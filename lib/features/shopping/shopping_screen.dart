import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

/// Liste de courses : progression, rayons repliables, cases larges, ajout rapide (§3.5).
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _draft = TextEditingController();
  final _collapsed = <Aisle>{};

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(appStoreProvider.notifier).addManualItem(_draft.text);
    _draft.clear();
  }

  String _asText(Group group, List<ShoppingItem> items) {
    final b = StringBuffer('Courses · ${group.name}\n');
    for (final aisle in Aisle.values) {
      final inAisle = items.where((i) => i.aisle == aisle && !i.checked).toList();
      if (inAisle.isEmpty) continue;
      b.writeln('\n${aisle.label}');
      for (final i in inAisle) {
        final q = formatQty(i.qty, i.unit);
        b.writeln('- ${i.label}${q.isEmpty ? '' : ' ($q)'}');
      }
    }
    return b.toString().trimRight();
  }

  Future<void> _editQty(ShoppingItem item) async {
    final text = await askText(
      context,
      title: 'Quantité · ${item.label}',
      hint: 'Ex. 2',
      initial: item.qty == item.qty.roundToDouble() ? item.qty.toStringAsFixed(0) : item.qty.toString(),
    );
    final v = double.tryParse((text ?? '').replaceAll(',', '.'));
    if (v != null && v > 0) ref.read(appStoreProvider.notifier).setItemQty(item.id, v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final group = ref.watch(currentGroupProvider);
    final items = ref.watch(groupShoppingProvider);
    final meta = ref.watch(appStoreProvider.select((d) => d.lists[d.currentGroupId]));
    final done = items.where((i) => i.checked).length;

    final subtitle = meta == null
        ? '${group.name} · ajouts libres'
        : '${group.name} · du ${dayMonth(meta.from)} au ${dayMonth(meta.to)} · ${pluralize(meta.meals, 'repas', 'repas')}';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Courses', style: c.heading(30, letterSpacing: -0.3))),
                    if (done > 0) ...[
                      RoundIconButton(
                        icon: Icons.delete_sweep_outlined,
                        label: 'Vider les articles cochés',
                        onTap: () => ref.read(appStoreProvider.notifier).clearChecked(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    RoundIconButton(
                      icon: Icons.ios_share,
                      label: 'Partager la liste',
                      onTap: () {
                        if (items.isEmpty) return;
                        SharePlus.instance.share(ShareParams(text: _asText(group, items)));
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: c.muted)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: items.isEmpty ? 0 : done / items.length,
                          minHeight: 8,
                          backgroundColor: c.outline,
                          valueColor: AlwaysStoppedAnimation(c.secondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done / ${items.length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.secondary)),
                  ]),
                ]),
              ),
              Expanded(
                child: items.isEmpty
                    ? _Empty(onPlan: () => context.go('/planning'))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        children: [
                          for (final aisle in Aisle.values)
                            if (items.any((i) => i.aisle == aisle)) ...[
                              _AisleSection(
                                aisle: aisle,
                                collapsed: _collapsed.contains(aisle),
                                items: [
                                  ...items.where((i) => i.aisle == aisle && !i.checked),
                                  ...items.where((i) => i.aisle == aisle && i.checked),
                                ],
                                onToggleCollapse: () => setState(() {
                                  if (!_collapsed.remove(aisle)) _collapsed.add(aisle);
                                }),
                                onEditQty: _editQty,
                              ),
                              const SizedBox(height: 14),
                            ],
                        ],
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.outline))),
                child: Row(children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.outline),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _draft,
                        textInputAction: TextInputAction.done,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _add(),
                        decoration: InputDecoration(
                          hintText: 'Ajouter un produit (lessive…)',
                          hintStyle: TextStyle(color: c.muted),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: true,
                    label: 'Ajouter',
                    child: Material(
                      color: c.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _add,
                        child: SizedBox(width: 48, height: 48, child: Icon(Icons.add, color: c.onPrimary)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPlan});

  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined, size: 48, color: c.muted),
          const SizedBox(height: 12),
          Text('Votre liste est vide', style: c.heading(22)),
          const SizedBox(height: 6),
          Text(
            'Générez-la depuis le planning, ou ajoutez un produit ci-dessous.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          PillButton(label: 'Aller au planning', expand: false, primary: false, onPressed: onPlan),
        ]),
      ),
    );
  }
}

class _AisleSection extends ConsumerWidget {
  const _AisleSection({
    required this.aisle,
    required this.collapsed,
    required this.items,
    required this.onToggleCollapse,
    required this.onEditQty,
  });

  final Aisle aisle;
  final bool collapsed;
  final List<ShoppingItem> items;
  final VoidCallback onToggleCollapse;
  final ValueChanged<ShoppingItem> onEditQty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final store = ref.read(appStoreProvider.notifier);
    final laterFrom = ref.watch(appStoreProvider.select((d) => d.lists[d.currentGroupId]?.from));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: onToggleCollapse,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 2),
          child: Row(children: [
            Expanded(child: Text(aisle.label.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.72, color: c.muted))),
            Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 18, color: c.muted),
          ]),
        ),
      ),
      if (!collapsed)
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.outline), borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            for (final (i, item) in items.indexed)
              Dismissible(
                key: ValueKey(item.id),
                background: _swipeBg(c.primaryContainer, c.onPrimaryContainer, Icons.edit_outlined, Alignment.centerLeft),
                secondaryBackground: _swipeBg(c.danger.withAlpha(40), c.danger, Icons.delete_outline, Alignment.centerRight),
                confirmDismiss: (dir) async {
                  if (dir == DismissDirection.startToEnd) {
                    onEditQty(item);
                    return false;
                  }
                  return true;
                },
                onDismissed: (_) => store.removeItem(item.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: i == items.length - 1 ? null : Border(bottom: BorderSide(color: c.surfaceVariant)),
                  ),
                  child: _ItemTile(
                    item: item,
                    laterFrom: laterFrom,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      store.toggleItem(item.id);
                    },
                  ),
                ),
              ),
          ]),
        ),
    ]);
  }

  Widget _swipeBg(Color bg, Color fg, IconData icon, Alignment align) => Container(
        color: bg,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(icon, color: fg),
      );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onTap, this.laterFrom});

  final ShoppingItem item;

  /// Début de la période de la liste : sert à signaler les produits frais à acheter plus tard.
  final DateTime? laterFrom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final from = item.manual ? 'Ajout manuel' : item.sources.join(', ');
    final qty = formatQty(item.qty, item.unit);
    return Semantics(
      checked: item.checked,
      inMutuallyExclusiveGroup: false,
      label: '${item.label} $qty',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.checked ? c.secondary : c.surface,
                  border: item.checked ? null : Border.all(color: c.checkOutline, width: 2),
                ),
                child: item.checked ? Icon(Icons.check, size: 16, color: c.onSecondary) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      decoration: item.checked ? TextDecoration.lineThrough : null,
                      color: item.checked ? c.muted : c.onSurface,
                    ),
                  ),
                  if (from.isNotEmpty) Text(from, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
                  if (laterFrom != null && item.buyLater(laterFrom!))
                    Text('Frais : à acheter plus tard (repas le ${dayMonth(item.firstUse!)})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.primary)),
                ]),
              ),
              Text(qty, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.soft)),
            ]),
          ),
        ),
      ),
    );
  }
}
