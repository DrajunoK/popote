import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/auth_service.dart';
import '../../data/sync_service.dart';
import '../../shared/widgets.dart';

/// Profil : apparence (4 thèmes, aperçu immédiat), réglages, compte (F-PRF-01…06).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(appStoreProvider);
    final store = ref.read(appStoreProvider.notifier);
    final user = data.user;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
              Row(children: [
                RoundIconButton(icon: Icons.chevron_left, label: 'Retour au planning', onTap: () => context.pop()),
                const SizedBox(width: 10),
                Text('Profil', style: c.heading(24)),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                InitialAvatar(user?.initial ?? '?', bg: c.primaryContainer, fg: c.onPrimaryContainer, size: 56),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? 'Invité', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(user == null || user.email.isEmpty ? 'Connecté avec Google' : user.email,
                      style: TextStyle(fontSize: 13, color: c.muted)),
                ]),
              ]),
              const SizedBox(height: 18),
              const SectionLabel('Apparence', bottom: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.45,
                children: [
                  for (final t in appThemes.values)
                    _ThemeCard(theme: t, selected: data.themeKey == t.key, onTap: () => store.setTheme(t.key)),
                ],
              ),
              const SizedBox(height: 18),
              const SectionLabel('Réglages', bottom: 10),
              Container(
                decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.outline), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const _InfoRow(label: 'Langue', value: 'Français', divider: true),
                  const _InfoRow(label: 'Taille du texte', value: 'Système', divider: true),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    value: data.remindSunday,
                    onChanged: store.setRemind,
                    title: const Text('Rappel du dimanche', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionLabel('Compte', bottom: 10),
              if (AuthService.configured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    switch (ref.watch(syncStatusProvider)) {
                      SyncStatus.syncing => 'Synchronisation en cours…',
                      SyncStatus.error => 'Synchronisation impossible pour l’instant (hors ligne ?). Vos données restent sur l’appareil.',
                      SyncStatus.idle => 'Données synchronisées.',
                    },
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: c.surface,
                    foregroundColor: c.onSurface,
                    side: BorderSide(color: c.outline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    // On envoie d'abord les dernières modifications : la déconnexion efface les données locales.
                    await ref.read(syncServiceProvider).flush();
                    await ref.read(authServiceProvider).signOut();
                  },
                  child: const Text('Se déconnecter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: c.danger, minimumSize: const Size.fromHeight(48)),
                onPressed: () => _confirmDelete(context, ref),
                child: const Text('Supprimer mon compte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer votre compte ?'),
        content: const Text(
            'Votre compte est supprimé et vous quittez tous vos groupes. Les espaces personnels sont effacés ; '
            'les groupes partagés restent aux autres membres. Cette action est définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    if (!await ref.read(authServiceProvider).deleteAccount()) {
      messenger.showSnackBar(const SnackBar(content: Text('Suppression impossible pour l’instant. Vérifiez votre connexion.')));
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.divider});

  final String label;
  final String value;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: divider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.outline))) : null,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 14, color: c.muted)),
      ]),
    );
  }
}

/// Carte de thème : aperçu des couleurs du thème (pas du thème courant).
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.selected, required this.onTap});

  final MijoteColors theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Thème ${theme.name}',
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? c.primary : c.outline, width: selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.background,
                    border: Border.all(color: theme.outline),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(height: 8, decoration: BoxDecoration(color: theme.onSurface, borderRadius: BorderRadius.circular(4))),
                    ),
                    Row(children: [
                      _dot(theme.primary),
                      const SizedBox(width: 4),
                      _dot(theme.secondary),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(theme.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(theme.hint, style: TextStyle(fontSize: 11, color: c.muted)),
                  ]),
                ),
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 14, color: c.onPrimary),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(width: 18, height: 18, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}
