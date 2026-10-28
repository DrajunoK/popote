import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../domain/shopping_generator.dart';
import '../../shared/widgets.dart';

/// Fiche recette : temps, portions (recalcul des quantités), ingrédients / étapes, planifier (F-REC-02, 07).
class RecipeDetailScreen extends ConsumerStatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  int? _servings;
  int _tab = 0;

  Future<void> _plan(Recipe r) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Planifier « ${r.title} »',
      locale: const Locale('fr'),
    );
    if (date == null || !mounted) return;
    final group = ref.read(currentGroupProvider);
    final slot = await showModalBottomSheet<SlotKind>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(alignment: Alignment.centerLeft, child: Text('Quel repas ?', style: context.c.heading(22))),
          ),
          for (final s in group.slots) ListTile(title: Text(s.label), onTap: () => Navigator.pop(ctx, s)),
        ]),
      ),
    );
    if (slot == null || !mounted) return;
    ref.read(appStoreProvider.notifier).setMeal(date, slot, recipeId: r.id, guests: _servings);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Ajouté : ${dayTitle(date)} · ${slot.label}')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final recipe = ref.watch(recipesByIdProvider)[widget.recipeId];
    if (recipe == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Recette introuvable.')));
    }
    final fav = ref.watch(appStoreProvider.select((d) => d.favorites.contains(recipe.id)));
    final last = ref.watch(lastCookedProvider)[recipe.id];
    final servings = _servings ?? recipe.servings;
    final factor = servings / recipe.servings;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
                  Row(children: [
                    RoundIconButton(icon: Icons.chevron_left, label: 'Retour', onTap: () => context.pop()),
                    const Spacer(),
                    RoundIconButton(
                      icon: fav ? Icons.favorite : Icons.favorite_border,
                      label: fav ? 'Retirer des favoris' : 'Ajouter aux favoris',
                      onTap: () => ref.read(appStoreProvider.notifier).toggleFavorite(recipe.id),
                    ),
                    const SizedBox(width: 8),
                    RoundIconButton(icon: Icons.edit_outlined, label: 'Modifier', onTap: () => context.push('/recipe/${recipe.id}/edit')),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(color: c.tile(0).bg, borderRadius: BorderRadius.circular(24)),
                    child: Icon(Icons.restaurant_menu, size: 48, color: c.tile(0).fg),
                  ),
                  const SizedBox(height: 16),
                  Text(recipe.title, style: c.heading(30, letterSpacing: -0.3)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (recipe.protein != null) ProteinBadge(recipe.protein!),
                    if (recipe.base != null) Tag(recipe.base!.label, bg: c.surfaceVariant, fg: c.soft),
                    if (recipe.dish != null) Tag(recipe.dish!.label, bg: c.surfaceVariant, fg: c.soft),
                    if (recipe.cuisine != null) Tag(recipe.cuisine!, bg: c.surfaceVariant, fg: c.soft),
                    if (recipe.kidFriendly) Tag('Enfants', bg: c.surfaceVariant, fg: c.soft),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Stat(icon: Icons.schedule, label: 'Préparation', value: formatDuration(recipe.prepMin)),
                    const SizedBox(width: 8),
                    _Stat(icon: Icons.local_fire_department_outlined, label: 'Cuisson', value: formatDuration(recipe.cookMin)),
                    const SizedBox(width: 8),
                    Expanded(child: _Servings(value: servings, onChanged: (v) => setState(() => _servings = v))),
                  ]),
                  const SizedBox(height: 8),
                  Text('Dernière fois : ${agoLabel(last, DateTime.now())}', style: TextStyle(fontSize: 13, color: c.muted)),
                  const SizedBox(height: 16),
                  if (recipe.isSimple)
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Repas simple : pas d’ingrédients ni d’étapes. Modifiez la recette pour qu’elle alimente la liste de courses.',
                        style: TextStyle(color: c.soft, height: 1.4),
                      ),
                    )
                  else ...[
                    SegmentedTabs(labels: const ['Ingrédients', 'Étapes'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                    const SizedBox(height: 12),
                    if (_tab == 0)
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(children: [
                          for (final (i, ing) in recipe.ingredients.indexed)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: i == recipe.ingredients.length - 1
                                  ? null
                                  : BoxDecoration(border: Border(bottom: BorderSide(color: c.surfaceVariant))),
                              child: Row(children: [
                                Expanded(child: Text(ing.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                                Text(_ingredientQty(ing, factor),
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.soft)),
                              ]),
                            ),
                        ]),
                      )
                    else
                      Column(children: [
                        for (final (i, step) in recipe.steps.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              InitialAvatar('${i + 1}', bg: c.primaryContainer, fg: c.onPrimaryContainer, size: 32),
                              const SizedBox(width: 12),
                              Expanded(child: Padding(padding: const EdgeInsets.only(top: 5), child: Text(step, style: const TextStyle(fontSize: 15, height: 1.45)))),
                            ]),
                          ),
                      ]),
                  ],
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.outline))),
                child: PillButton(label: 'Planifier', icon: Icons.event_available, onPressed: () => _plan(recipe)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _ingredientQty(RecipeIngredient ing, double factor) {
    final (q, u) = normalizeUnit(ing.qty * factor, ing.unit);
    if (u == '') return '';
    return formatQty(smartRound(q, u), u);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.outline), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: c.muted),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
        ]),
      ),
    );
  }
}

class _Servings extends StatelessWidget {
  const _Servings({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.outline), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text('Portions', style: TextStyle(fontSize: 12, color: c.muted)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Moins',
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Plus',
            onPressed: value < 40 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ]),
      ]),
    );
  }
}
