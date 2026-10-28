import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'recipe_visual.dart';
import 'widgets.dart';

/// Choix de l'utilisateur dans le sélecteur de repas.
class MealPick {
  const MealPick.recipe(String this.recipeId) : freeText = null;
  const MealPick.note(String this.freeText) : recipeId = null;

  final String? recipeId;
  final String? freeText;
}

/// Bottom sheet « Choisir un repas » (F-PLN-03) : Favoris / Récents / Tous + création.
Future<MealPick?> showMealPicker(BuildContext context, {required String subtitle}) =>
    showModalBottomSheet<MealPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _MealPickerSheet(subtitle: subtitle),
    );

class _MealPickerSheet extends ConsumerStatefulWidget {
  const _MealPickerSheet({required this.subtitle});

  final String subtitle;

  @override
  ConsumerState<_MealPickerSheet> createState() => _MealPickerSheetState();
}

class _MealPickerSheetState extends ConsumerState<_MealPickerSheet> {
  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final data = ref.watch(appStoreProvider);
    final lastCooked = ref.watch(lastCookedProvider);
    final today = DateTime.now();

    var list = switch (_tab) {
      0 => data.recipes.where((r) => data.favorites.contains(r.id)).toList(),
      1 => (data.recipes.where((r) => lastCooked.containsKey(r.id)).toList()
        ..sort((a, b) => lastCooked[b.id]!.compareTo(lastCooked[a.id]!))),
      _ => [...data.recipes]..sort((a, b) => a.title.compareTo(b.title)),
    };
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = data.recipes.where((r) => r.title.toLowerCase().contains(q)).toList();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: c.outlineStrong, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.subtitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
            const SizedBox(height: 2),
            Text('Choisir un repas', style: c.heading(24)),
            const SizedBox(height: 14),
            SearchBox(hint: 'Rechercher un repas…', onChanged: (v) => setState(() => _query = v)),
            const SizedBox(height: 14),
            SegmentedTabs(
              labels: const ['Favoris', 'Récents', 'Tous'],
              index: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        _tab == 0 ? 'Aucun favori pour l’instant.\nAjoutez un ♥ depuis les recettes.' : 'Rien ici pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = list[i];
                        return _MealRow(
                          recipe: r,
                          tone: c.tile(i),
                          meta: '${formatDuration(r.totalMin)} · ${agoLabel(lastCooked[r.id], today)}',
                          favorite: data.favorites.contains(r.id),
                          onTap: () => Navigator.pop(context, MealPick.recipe(r.id)),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DashedBox(
                  radius: 26,
                  onTap: () async {
                    final name = await askText(context, title: 'Nouveau repas', hint: 'Ex. Pizza maison');
                    if (name == null || name.isEmpty || !context.mounted) return;
                    final id = ref.read(appStoreProvider.notifier).newId();
                    ref.read(appStoreProvider.notifier).upsertRecipe(Recipe(id: id, title: name));
                    Navigator.pop(context, MealPick.recipe(id));
                  },
                  child: SizedBox(
                    height: 52,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add, size: 18, color: c.primary),
                      const SizedBox(width: 8),
                      Text('Nouveau repas', style: TextStyle(fontWeight: FontWeight.w600, color: c.primary)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PillButton(
                label: 'Note libre',
                primary: false,
                expand: false,
                onPressed: () async {
                  final text = await askText(context, title: 'Note libre', hint: 'Restes, au resto, chez mamie…');
                  if (text == null || text.isEmpty || !context.mounted) return;
                  Navigator.pop(context, MealPick.note(text));
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.recipe, required this.tone, required this.meta, required this.favorite, required this.onTap});

  final Recipe recipe;
  final Tone tone;
  final String meta;
  final bool favorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.outline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            RecipeVisual(recipe: recipe, tone: tone, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(recipe.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(meta, style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
            ),
            if (favorite)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.favorite, size: 20, color: c.primary, semanticLabel: 'Favori'),
              ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Icon(Icons.add, size: 18, color: c.onPrimaryContainer),
            ),
          ]),
        ),
      ),
    );
  }
}
