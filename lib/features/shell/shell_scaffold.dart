import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../shared/widgets.dart';

/// Largeurs de rupture (spec §6.3).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;
}

const _destinations = [
  (Icons.calendar_month_outlined, Icons.calendar_month, 'Planning'),
  (Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Recettes'),
  (Icons.shopping_cart_outlined, Icons.shopping_cart, 'Courses'),
  (Icons.group_outlined, Icons.group, 'Groupe'),
];

/// Navigation adaptative : barre en bas < 600 dp, rail à gauche au-delà.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    if (width < Breakpoints.medium) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
          ],
        ),
      );
    }

    final c = context.c;
    final group = ref.watch(currentGroupProvider);
    final user = ref.watch(appStoreProvider.select((d) => d.user));
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          labelType: NavigationRailLabelType.all,
          minWidth: 88,
          leading: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Color(group.color), borderRadius: BorderRadius.circular(14)),
              child: Text(
                group.initial,
                style: c.heading(22, color: const Color(0xFF14161B)),
              ),
            ),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Semantics(
                  label: 'Mon profil',
                  button: true,
                  child: Tooltip(
                    message: user?.name ?? 'Mon profil',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => context.push('/profile'),
                      child: InitialAvatar(user?.initial ?? '?', bg: c.surfaceVariant, fg: c.onSurface, size: 44),
                    ),
                  ),
                ),
              ),
            ),
          ),
          destinations: [
            for (final d in _destinations)
              NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
          ],
        ),
        VerticalDivider(width: 1, color: c.outline),
        Expanded(child: shell),
      ]),
    );
  }
}
