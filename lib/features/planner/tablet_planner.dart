import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/recipe_visual.dart';
import '../../shared/widgets.dart';
import 'entry_actions.dart';
import 'planner_screen.dart';

/// Planning en 2 panneaux (tablette paysage) : grille de la semaine à gauche,
/// bibliothèque à droite, glisser-déposer d'une recette sur un créneau (F-PLN-04).
class TabletPlanner extends ConsumerStatefulWidget {
  const TabletPlanner({super.key});

  @override
  ConsumerState<TabletPlanner> createState() => _TabletPlannerState();
}

class _TabletPlannerState extends ConsumerState<TabletPlanner> {
  /// Semaines affichées à la suite (la première est la semaine choisie).
  static const _weeksShown = 8;

  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final monday = ref.watch(visibleWeekProvider);
    final group = ref.watch(currentGroupProvider);
    final entries = ref.watch(groupEntriesProvider);
    final recipes = ref.watch(recipesByIdProvider);
    final today = dateOnly(DateTime.now());
    return Scaffold(
      body: Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                IconButton(
                  tooltip: 'Semaine précédente',
                  onPressed: () => ref.read(visibleWeekProvider.notifier).shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${group.name} · ${weekLabel(monday)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.muted)),
                    const SizedBox(height: 4),
                    Text('On mange quoi ?', style: c.heading(34, letterSpacing: -0.3)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Semaine suivante',
                  onPressed: () => ref.read(visibleWeekProvider.notifier).shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Vue du mois',
                  onPressed: () => context.push('/month'),
                  icon: const Icon(Icons.calendar_view_month_outlined),
                ),
                const SizedBox(width: 8),
                PillButton(
                  label: 'Remplir la semaine',
                  icon: Icons.auto_awesome,
                  primary: false,
                  expand: false,
                  height: 48,
                  onPressed: () => context.push('/magic'),
                ),
                const SizedBox(width: 10),
                PillButton(
                  label: 'Générer les courses',
                  icon: Icons.shopping_cart_outlined,
                  expand: false,
                  height: 48,
                  onPressed: () => generateShoppingList(context, ref),
                ),
              ]),
              const SizedBox(height: 20),
              Expanded(
                // Plusieurs semaines empilées : avec un seul repas par jour, une semaine ne remplit
                // pas la hauteur de l'écran, autant voir les suivantes sans changer de page.
                child: ListView.builder(
                  itemCount: _weeksShown,
                  itemBuilder: (_, w) => _WeekBlock(
                    monday: DateTime(monday.year, monday.month, monday.day + 7 * w),
                    first: w == 0,
                    today: today,
                    slots: group.slots,
                    entries: entries,
                    recipes: recipes,
                  ),
                ),
              ),
            ]),
          ),
        ),
        _Library(
          tab: _tab,
          query: _query,
          onTab: (i) => setState(() => _tab = i),
          onQuery: (q) => setState(() => _query = q),
        ),
      ]),
    );
  }
}

class _SlotCell extends ConsumerWidget {
  const _SlotCell({required this.date, required this.slot, required this.entry, required this.recipes});

  final DateTime date;
  final SlotKind slot;
  final PlanEntry? entry;
  final Map<String, Recipe> recipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return DragTarget<Object>(
      onWillAcceptWithDetails: (d) => d.data is RecipeDrag || d.data is EntryDrag,
      onAcceptWithDetails: (d) => dropOnSlot(ref, d.data, date, slot),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final e = entry;
        if (e == null) {
          return DashedBox(
            radius: 16,
            strokeWidth: hovering ? 2 : 1.5,
            color: hovering ? c.primary : c.outlineStrong,
            fill: hovering ? c.primaryContainer : null,
            onTap: () => addMealToSlot(context, ref, date, slot),
            child: SizedBox.expand(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add, size: 22, color: c.primary),
                const SizedBox(height: 6),
                Text('Déposer ici', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.primary)),
              ]),
            ),
          );
        }
        final recipe = recipes[e.recipeId];
        final title = recipe?.title ?? e.freeText ?? 'Repas';
        final card = _filledCell(context, ref, e, recipe, title, hovering);
        return LongPressDraggable<Object>(
          data: EntryDrag(e.id),
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 150, child: Opacity(opacity: 0.92, child: card)),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: card,
        );
      },
    );
  }

  Widget _filledCell(BuildContext context, WidgetRef ref, PlanEntry e, Recipe? recipe, String title, bool hovering) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: hovering ? c.primary : c.outline, width: hovering ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showEntryActions(context, ref, e),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (recipe != null)
              RecipeVisual(recipe: recipe, tone: c.slotTone(slot), height: 56, radius: 10, emojiSize: 28)
            else
              Container(
                height: 56,
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(10)),
              ),
            const SizedBox(height: 6),
            Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 6),
            Text(recipe == null || recipe.totalMin == 0 ? 'Note' : formatDuration(recipe.totalMin),
                style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        ),
      ),
    );
  }
}

class _Library extends ConsumerWidget {
  const _Library({required this.tab, required this.query, required this.onTab, required this.onQuery});

  final int tab;
  final String query;
  final ValueChanged<int> onTab;
  final ValueChanged<String> onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final data = ref.watch(appStoreProvider);
    final lastCooked = ref.watch(lastCookedProvider);

    var list = switch (tab) {
      0 => data.recipes.where((r) => data.favorites.contains(r.id)).toList(),
      1 => (data.recipes.where((r) => lastCooked.containsKey(r.id)).toList()
        ..sort((a, b) => lastCooked[b.id]!.compareTo(lastCooked[a.id]!))),
      _ => [...data.recipes]..sort((a, b) => a.title.compareTo(b.title)),
    };
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) list = data.recipes.where((r) => r.title.toLowerCase().contains(q)).toList();

    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      decoration: BoxDecoration(color: c.surface, border: Border(left: BorderSide(color: c.outline))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Glisser une recette', style: c.heading(22)),
        const SizedBox(height: 14),
        SearchBox(hint: 'Rechercher…', onChanged: onQuery, height: 44, filled: c.background),
        const SizedBox(height: 14),
        Row(children: [
          for (final (i, label) in const ['Favoris', 'Récents', 'Tous'].indexed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterPill(label: label, active: tab == i && q.isEmpty, height: 32, onTap: () => onTab(i)),
            ),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = list[i];
              final row = _LibraryRow(recipe: r, tone: c.tile(i));
              return LongPressDraggable<Object>(
                data: RecipeDrag(r.id),
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(width: 300, child: Transform.rotate(angle: -0.035, child: _LibraryRow(recipe: r, tone: c.tile(i), lifted: true))),
                ),
                childWhenDragging: Opacity(opacity: 0.4, child: row),
                child: row,
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.recipe, required this.tone, this.lifted = false});

  final Recipe recipe;
  final Tone tone;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lifted ? c.surface : c.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lifted ? c.primary : c.outline),
        boxShadow: lifted ? [BoxShadow(color: Colors.black.withAlpha(115), blurRadius: 20, offset: const Offset(0, 8))] : null,
      ),
      child: Row(children: [
        Icon(Icons.drag_indicator, size: 16, color: c.muted),
        const SizedBox(width: 10),
        RecipeVisual(recipe: recipe, tone: tone, size: 44, radius: 10),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(formatDuration(recipe.totalMin), style: TextStyle(fontSize: 12, color: c.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// Une semaine : en-tête des jours puis une ligne par créneau, de hauteur fixe.
class _WeekBlock extends StatelessWidget {
  const _WeekBlock({
    required this.monday,
    required this.first,
    required this.today,
    required this.slots,
    required this.entries,
    required this.recipes,
  });

  // Assez haut pour un titre sur 3 lignes (ex. « Risotto champignons » dans une colonne étroite).
  static const slotHeight = 184.0;

  final DateTime monday;
  final bool first;
  final DateTime today;
  final List<SlotKind> slots;
  final List<PlanEntry> entries;
  final Map<String, Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!first)
          Padding(
            padding: const EdgeInsets.only(left: 64, bottom: 6),
            child: Text(weekLabel(monday), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
          ),
        SizedBox(
          height: 48,
          child: Row(children: [
            const SizedBox(width: 64),
            for (final d in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: d == today ? c.primary : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(weekdayShort[d.weekday - 1],
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500, color: d == today ? c.onPrimary : c.onSurface)),
                      Text('${d.day}',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600, color: d == today ? c.onPrimary : c.onSurface)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        for (final slot in slots)
          SizedBox(
            height: slotHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                SizedBox(
                  width: 64,
                  child: Text(slot.label.toUpperCase(),
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.66, color: c.slotColor(slot))),
                ),
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _SlotCell(
                        date: d,
                        slot: slot,
                        entry: entries.where((e) => e.date == d && e.slot == slot).firstOrNull,
                        recipes: recipes,
                      ),
                    ),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}
