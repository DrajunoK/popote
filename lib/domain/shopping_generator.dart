import 'dart:math' as math;

import '../data/models.dart';

class _Acc {
  _Acc(this.label, this.unit, this.aisle);
  final String label;
  final String unit;
  final Aisle aisle;
  double qty = 0;
  final Set<String> sources = {};
}

/// Ramène les unités compatibles à une base commune (g, ml) — F-SHP-02.
(double, String) normalizeUnit(double qty, String unit) => switch (unit) {
      'kg' => (qty * 1000, 'g'),
      'l' => (qty * 1000, 'ml'),
      'cl' => (qty * 10, 'ml'),
      _ => (qty, unit),
    };

/// Arrondi « intelligent » : 0,4 oignon → 1 oignon, 403 g → 405 g.
double smartRound(double qty, String unit) {
  switch (unit) {
    case 'pièce':
      return math.max(1, (qty - 0.001).ceilToDouble());
    case 'g':
    case 'ml':
      return math.max(5, (qty / 5).round() * 5.0);
    case '':
      return 0;
    default:
      return (qty * 2).ceilToDouble() / 2;
  }
}

/// Génère la liste de courses d'un groupe (§5.5).
///
/// - agrège les ingrédients identiques et convertit les unités compatibles ;
/// - exclut le placard (`pantry`) ;
/// - conserve les ajouts manuels et l'état coché des articles reconduits (F-SHP-07).
List<ShoppingItem> generateShopping({
  required String groupId,
  required List<PlanEntry> entries,
  required Map<String, Recipe> recipes,
  required Set<String> pantry,
  required List<ShoppingItem> existing,
  required String Function() newId,
}) {
  final acc = <String, _Acc>{};
  for (final e in entries) {
    final recipe = e.recipeId == null ? null : recipes[e.recipeId];
    if (recipe == null || recipe.isSimple) continue;
    final factor = e.guests / math.max(recipe.servings, 1);
    for (final ing in recipe.ingredients) {
      if (pantry.contains(ing.name.toLowerCase())) continue;
      final (q, u) = normalizeUnit(ing.qty * factor, ing.unit);
      final key = '${ing.name.toLowerCase()}|$u';
      final a = acc.putIfAbsent(key, () => _Acc(ing.name, u, ing.aisle));
      a.qty += q;
      a.sources.add(recipe.title);
    }
  }

  final previous = {
    for (final it in existing.where((i) => i.groupId == groupId && !i.manual)) it.key: it,
  };
  final manual = existing.where((i) => i.groupId == groupId && i.manual).toList();

  final generated = acc.values.map((a) {
    final key = '${a.label.toLowerCase()}|${a.unit}';
    final old = previous[key];
    return ShoppingItem(
      id: old?.id ?? newId(),
      groupId: groupId,
      label: a.label,
      qty: smartRound(a.qty, a.unit),
      unit: a.unit,
      aisle: a.aisle,
      manual: false,
      sources: (a.sources.toList()..sort()),
      checked: old?.checked ?? false,
    );
  }).toList()
    ..sort((a, b) => a.aisle.index != b.aisle.index ? a.aisle.index - b.aisle.index : a.label.compareTo(b.label));

  return [...generated, ...manual];
}
