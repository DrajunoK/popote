import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/app_store.dart';
import '../data/sync_service.dart';
import '../features/auth/login_screen.dart';
import '../features/groups/group_screen.dart';
import '../features/planner/magic_screen.dart';
import '../features/planner/month_screen.dart';
import '../features/planner/planner_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recipes/recipe_detail_screen.dart';
import '../features/recipes/recipe_editor_screen.dart';
import '../features/recipes/recipes_screen.dart';
import '../features/shell/shell_scaffold.dart';
import '../features/shopping/shopping_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier<bool>(ref.read(appStoreProvider).user != null);
  ref.listen(appStoreProvider.select((d) => d.user != null), (_, next) => signedIn.value = next);
  ref.onDispose(signedIn.dispose);

  return GoRouter(
    initialLocation: '/planning',
    refreshListenable: signedIn,
    redirect: (context, state) {
      // Liens profonds : `app.popote://join/CODE` (invitation) ou `app.popote://login-callback` (retour Google).
      final uri = state.uri;
      if (uri.scheme == 'app.popote') {
        if (uri.host == 'join' && uri.pathSegments.isNotEmpty) {
          ref.read(syncServiceProvider).joinWithCode(uri.pathSegments.first);
          return signedIn.value ? '/group' : '/login';
        }
        return signedIn.value ? '/planning' : '/login';
      }
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn.value) return atLogin ? null : '/login';
      return atLogin ? '/planning' : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/planning', builder: (_, __) => const PlannerScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/recipes', builder: (_, __) => const RecipesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/shopping', builder: (_, __) => const ShoppingScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/group', builder: (_, __) => const GroupScreen())]),
        ],
      ),
      GoRoute(path: '/month', builder: (_, __) => const MonthScreen()),
      GoRoute(path: '/magic', builder: (_, __) => const MagicScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/recipe/new', builder: (_, __) => const RecipeEditorScreen()),
      GoRoute(
        path: '/recipe/:id',
        builder: (_, s) => RecipeDetailScreen(recipeId: s.pathParameters['id']!),
        routes: [
          GoRoute(path: 'edit', builder: (_, s) => RecipeEditorScreen(recipeId: s.pathParameters['id'])),
        ],
      ),
    ],
  );
});
