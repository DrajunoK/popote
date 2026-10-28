import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/recipe_visual.dart';
import '../../shared/widgets.dart';

const _filters = ['Tous', 'Favoris', 'Rapide', 'Végétarien', 'Enfants'];

/// Bibliothèque de recettes : grille de cartes, recherche, filtres, favoris (F-REC-01, 04).
class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  String _filter = 'Tous';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = ref.watch(appStoreProvider);
    final q = _query.trim().toLowerCase();

    final shown = data.recipes.where((r) {
      final okFilter = switch (_filter) {
        'Tous' => true,
        'Favoris' => data.favorites.contains(r.id),
        _ => r.allTags.contains(_filter),
      };
      if (!okFilter) return false;
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.ingredients.any((i) => i.name.toLowerCase().contains(q)) ||
          r.allTags.any((t) => t.toLowerCase().contains(q));
    }).toList();

    final width = MediaQuery.of(context).size.width;
    final columns = width < 600 ? 2 : (width < 900 ? 3 : 4);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recipe/new'),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle recette', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Recettes', style: c.heading(30, letterSpacing: -0.3)),
                Text(pluralize(data.recipes.length, 'recette'), style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
              const SizedBox(height: 14),
              SearchBox(hint: 'Plat, ingrédient, tag…', onChanged: (v) => setState(() => _query = v)),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => FilterPill(
                    label: _filters[i],
                    active: _filter == _filters[i],
                    onTap: () => setState(() => _filter = _filters[i]),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        _filter == 'Favoris' && q.isEmpty
                            ? 'Aucun favori pour l’instant.\nTouchez le ♥ d’une recette pour la retrouver ici.'
                            : 'Aucune recette ne correspond.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, height: 1.4),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 96),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 196,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _RecipeCard(
                      recipe: shown[i],
                      tone: c.tile(i),
                      favorite: data.favorites.contains(shown[i].id),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({required this.recipe, required this.tone, required this.favorite});

  final Recipe recipe;
  final Tone tone;
  final bool favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: c.outline)),
      child: InkWell(
        onTap: () => context.push('/recipe/${recipe.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 112,
            child: Stack(children: [
              Positioned.fill(child: RecipeVisual(recipe: recipe, tone: tone, radius: 0, emojiSize: 44)),
              Positioned(
                top: 8,
                right: 8,
                child: Semantics(
                  button: true,
                  label: favorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                  child: Material(
                    color: c.surface,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ref.read(appStoreProvider.notifier).toggleFavorite(recipe.id),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(favorite ? Icons.favorite : Icons.favorite_border, size: 18, color: c.primary),
                      ),
                    ),
                  ),
                ),
              ),
              if (recipe.protein != null) Positioned(left: 8, bottom: 8, child: ProteinBadge(recipe.protein!)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule, size: 14, color: c.muted),
                const SizedBox(width: 4),
                Text(formatDuration(recipe.totalMin), style: TextStyle(fontSize: 12, color: c.muted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
