import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

/// Groupe : invitation par lien / QR, membres et rôles, autres groupes (§3.2).
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key});

  /// TODO(backend) : le jeton doit être émis par la table `invitations` (expiration 7 jours).
  String _inviteLink(Group g) => 'https://popote.app/join/${g.id}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(appStoreProvider);
    final group = data.currentGroup;
    final others = data.groups.where((g) => g.id != group.id && !g.archived).toList();
    final link = _inviteLink(group);
    final slotsLabel = group.slots.map((s) => s.label).join(' + ');
    final subtitle = switch (group.period) {
      PeriodType.stay when group.startDate != null && group.endDate != null =>
        'Weekend · ${dayMonth(group.startDate!)} – ${dayMonth(group.endDate!)} · $slotsLabel',
      _ => '${group.period.label} · $slotsLabel',
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
              Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Color(group.color), borderRadius: BorderRadius.circular(18)),
                  child: Text(group.initial, style: c.heading(26, color: const Color(0xFF14161B))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(group.name, style: c.heading(26)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: c.muted)),
                  ]),
                ),
                RoundIconButton(
                  icon: Icons.tune,
                  label: 'Paramètres du groupe',
                  onTap: () => _slotsSheet(context, ref, group),
                ),
              ]),
              const SizedBox(height: 16),
              if (!group.personal)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: c.inverse, borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: c.isDark ? c.surface : c.onInverse, borderRadius: BorderRadius.circular(10)),
                      child: Semantics(
                        label: 'QR code d’invitation',
                        child: QrImageView(
                          data: link,
                          size: 96,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: c.inverse),
                          dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: c.inverse),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Inviter dans le groupe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.onInverse)),
                        const SizedBox(height: 4),
                        Text('Scannez ou partagez le lien. Valable 7 jours.',
                            style: TextStyle(fontSize: 13, height: 1.4, color: c.onInverse.withAlpha(200))),
                        const SizedBox(height: 10),
                        Material(
                          color: c.isDark ? c.surface : c.onInverse,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => SharePlus.instance.share(ShareParams(text: 'Rejoins « ${group.name} » sur Popote : $link')),
                            child: SizedBox(
                              height: 44,
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.link, size: 18, color: c.isDark ? c.onSurface : c.inverse),
                                const SizedBox(width: 8),
                                Text('Partager le lien',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.isDark ? c.onSurface : c.inverse)),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              SectionLabel('Membres · ${group.members.length}'),
              Container(
                decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.outline), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  for (final (i, m) in group.members.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: i == group.members.length - 1
                          ? null
                          : BoxDecoration(border: Border(bottom: BorderSide(color: c.surfaceVariant))),
                      child: Row(children: [
                        InitialAvatar(m.name.substring(0, 1).toUpperCase(), bg: c.tile(i + 2).bg, fg: c.onSurface),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(TextSpan(
                            text: m.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            children: [
                              if (m.isMe) TextSpan(text: ' (vous)', style: TextStyle(fontWeight: FontWeight.w400, color: c.muted)),
                            ],
                          )),
                        ),
                        _RoleTag(m.role),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Mes autres groupes'),
              for (final g in others) ...[
                _GroupRow(group: g, onTap: () => ref.read(appStoreProvider.notifier).selectGroup(g.id)),
                const SizedBox(height: 8),
              ],
              DashedBox(
                radius: 16,
                onTap: () => _createGroup(context, ref),
                child: SizedBox(
                  height: 52,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add, size: 18, color: c.primary),
                    const SizedBox(width: 8),
                    Text('Créer un groupe', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.primary)),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _slotsSheet(BuildContext context, WidgetRef ref, Group group) {
    return showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => Consumer(builder: (ctx, ref, _) {
        final current = ref.watch(currentGroupProvider);
        final c = ctx.c;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Créneaux du planning', style: c.heading(22)),
              const SizedBox(height: 4),
              Text('Les repas à planifier chaque jour.', style: TextStyle(color: c.muted)),
              const SizedBox(height: 8),
              for (final s in SlotKind.values)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.label),
                  value: current.slots.contains(s),
                  onChanged: (on) {
                    final next = [
                      for (final k in SlotKind.values)
                        if (k == s ? on == true : current.slots.contains(k)) k,
                    ];
                    if (next.isEmpty) return;
                    ref.read(appStoreProvider.notifier).setSlots(current.id, next);
                  },
                ),
            ]),
          ),
        );
      }),
    );
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final name = await askText(context, title: 'Nouveau groupe', hint: 'Ex. Chalet entre amis');
    if (name == null || name.isEmpty || !context.mounted) return;
    final c = context.c;
    final colors = [c.tertiary, c.slotLunch, c.primary, const Color(0xFF8CC0E8)];
    final colorValue = colors[ref.read(appStoreProvider).groups.length % colors.length].toARGB32();
    ref.read(appStoreProvider.notifier).createGroup(name, PeriodType.week, colorValue);
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag(this.role);

  final Role role;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return switch (role) {
      Role.admin => Tag(role.label, bg: c.primaryContainer, fg: c.onPrimaryContainer),
      Role.member => Tag(role.label, bg: c.tiles[1].bg, fg: c.tiles[1].fg),
      Role.viewer => Tag(role.label, bg: c.surfaceVariant, fg: c.soft),
    };
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sub = group.personal
        ? 'Espace personnel'
        : group.period == PeriodType.stay && group.startDate != null && group.endDate != null
            ? 'Weekend · ${dayMonth(group.startDate!)} – ${dayMonth(group.endDate!)} · ${group.size} pers.'
            : '${group.period.label} · ${group.size} pers.';
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.outline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Color(group.color), borderRadius: BorderRadius.circular(12)),
              child: Text(group.initial, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF14161B))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(sub, style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: c.muted),
          ]),
        ),
      ),
    );
  }
}
