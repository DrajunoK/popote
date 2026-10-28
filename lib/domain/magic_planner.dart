import 'dart:math' as math;

import '../data/models.dart';

/// Un créneau du planning (date + repas).
class PlanSlot {
  const PlanSlot(this.date, this.kind);

  final DateTime date;
  final SlotKind kind;

  /// Ordre chronologique : jour × 10 + position du repas.
  int get ord => dayIndex(date) * 10 + kind.index;
  int get day => dayIndex(date);
  bool get isWeekday => date.weekday <= DateTime.friday;
}

class MagicResult {
  const MagicResult(this.picks, this.warnings);

  /// Recette proposée par `PlanSlot.ord` (absente = impossible de remplir).
  final Map<int, Recipe> picks;
  final List<String> warnings;
}

/// Planification automatique (§3.8) : remplissage glouton avec score, local donc
/// utilisable hors-ligne.
///
/// [fixed] contient les repas déjà présents ou verrouillés : ils servent de contraintes.
/// [lastCooked] donne la dernière date de cuisine par recette (hors semaine planifiée).
/// Un même [seed] donne toujours la même proposition (annuler / rejouer).
MagicResult planMagic({
  required List<PlanSlot> slots,
  required List<Recipe> candidates,
  required Map<int, Recipe> fixed,
  required Map<String, DateTime> lastCooked,
  required Set<String> favorites,
  required PlannerRules rules,
  required int seed,
  required DateTime today,
}) {
  final rnd = math.Random(seed);
  final placed = Map<int, Recipe>.from(fixed);
  final order = [...slots]..sort((a, b) => a.ord.compareTo(b.ord));
  final pool = candidates.where((r) => r.isCategorized).toList();
  final warnings = <String>[];
  final picks = <int, Recipe>{};

  if (pool.length < order.length) {
    warnings.add('Moins de ${order.length} recettes catégorisées — ajoutez-en pour plus de variété.');
  }

  for (var idx = 0; idx < order.length; idx++) {
    final slot = order[idx];
    final remaining = order.length - idx;
    Recipe? chosen;
    var found = 0;
    for (var level = 0; level <= 3 && chosen == null; level++) {
      final scored = <(Recipe, double)>[];
      for (final r in pool) {
        final s = _score(r, slot, placed, remaining, lastCooked, favorites, rules, today, level);
        if (s != null) scored.add((r, s));
      }
      if (scored.isEmpty) continue;
      scored.sort((a, b) => b.$2.compareTo(a.$2));
      chosen = _weightedPick(scored.take(5).toList(), rnd);
      found = level;
    }
    if (chosen == null) continue;
    if (found > 1) {
      const msg = 'Pas assez de recettes pour respecter toutes les règles — certaines ont été assouplies.';
      if (!warnings.contains(msg)) warnings.add(msg);
    }
    placed[slot.ord] = chosen;
    picks[slot.ord] = chosen;
  }

  int count(bool Function(Recipe) test) => placed.values.where(test).length;
  if (rules.fish && count((r) => r.protein == Protein.fish) < rules.minFish && order.isNotEmpty) {
    warnings.add('Pas assez de recettes poisson — ajoutez-en ou désactivez la règle.');
  }
  if (rules.veg && count((r) => r.protein?.isMeatless ?? false) < rules.minVeg && order.isNotEmpty) {
    warnings.add('Pas assez de recettes végétariennes — ajoutez-en ou désactivez la règle.');
  }
  if (picks.length < order.length) {
    warnings.add('${order.length - picks.length} créneau(x) non rempli(s) : bibliothèque trop petite.');
  }
  return MagicResult(picks, warnings);
}

Recipe _weightedPick(List<(Recipe, double)> top, math.Random rnd) {
  final min = top.map((e) => e.$2).reduce(math.min);
  // Décale les poids pour qu'ils restent positifs.
  final weights = top.map((e) => e.$2 - min + 0.05).toList();
  final total = weights.reduce((a, b) => a + b);
  var x = rnd.nextDouble() * total;
  for (var i = 0; i < top.length; i++) {
    x -= weights[i];
    if (x <= 0) return top[i].$1;
  }
  return top.last.$1;
}

/// Score d'une recette pour un créneau, `null` si une règle « dure » est violée au
/// niveau d'assouplissement [level] (0 = toutes les règles, 3 = seulement « pas de doublon »).
double? _score(
  Recipe r,
  PlanSlot slot,
  Map<int, Recipe> placed,
  int remaining,
  Map<String, DateTime> lastCooked,
  Set<String> favorites,
  PlannerRules rules,
  DateTime today,
  int level,
) {
  // Toujours : pas deux fois la même recette dans la période.
  if (placed.values.any((p) => p.id == r.id)) return null;

  final last = lastCooked[r.id];
  final daysSince = last == null ? 60 : today.difference(last).inDays;

  if (level <= 0) {
    if (rules.season && !r.season.matches(slot.date)) return null;
    if (last != null && daysSince < rules.historyDays) return null;
  }
  if (level <= 2 && rules.quick && slot.isWeekday && r.effort == Effort.long) return null;
  if (level <= 1 && r.protein!.isRedMeat) {
    final red = placed.values.where((p) => p.protein?.isRedMeat ?? false).length;
    if (red >= rules.maxRedMeat) return null;
  }

  // Voisins chronologiques (repas précédent / suivant déjà placés).
  Recipe? prev, next;
  var prevOrd = -1 << 60, nextOrd = 1 << 60;
  placed.forEach((ord, p) {
    if (ord < slot.ord && ord > prevOrd) {
      prevOrd = ord;
      prev = p;
    }
    if (ord > slot.ord && ord < nextOrd) {
      nextOrd = ord;
      next = p;
    }
  });
  final sameDay = placed.entries.where((e) => e.key ~/ 10 == slot.day).map((e) => e.value);
  final adjacentDays =
      placed.entries.where((e) => (e.key ~/ 10 - slot.day).abs() == 1).map((e) => e.value).toList();

  if (rules.vary) {
    if (level <= 2) {
      if (prev?.protein == r.protein || next?.protein == r.protein) return null;
      if (sameDay.any((p) => p.protein == r.protein)) return null;
    }
    if (level <= 1) {
      if (adjacentDays.any((p) => p.base == r.base)) return null;
      if (placed.values.where((p) => p.base == r.base).length >= 2) return null;
      if (r.dish != null && adjacentDays.any((p) => p.dish == r.dish)) return null;
    }
  }

  var score = (favorites.contains(r.id) ? rules.favoriteWeight : 1.0) * (0.2 + math.min(daysSince, 60) / 60);

  // Quotas : bonus aux catégories qui risquent de devenir inatteignables.
  double quota(bool enabled, int min, bool Function(Recipe) test) {
    if (!enabled) return 1;
    final have = placed.values.where(test).length;
    final need = min - have;
    if (need <= 0) return 1;
    if (test(r)) return remaining <= need ? 6 : 1.6;
    return remaining <= need ? 0.2 : 1;
  }

  score *= quota(rules.veg, rules.minVeg, (x) => x.protein?.isMeatless ?? false);
  score *= quota(rules.fish, rules.minFish, (x) => x.protein == Protein.fish);

  // Pénalités légères : base / cuisine / protéine déjà vues dans la semaine.
  if (placed.values.any((p) => p.base == r.base)) score *= 0.7;
  if (r.cuisine != null && placed.values.any((p) => p.cuisine == r.cuisine)) score *= 0.9;
  if (placed.values.any((p) => p.protein == r.protein)) score *= 0.85;
  return score;
}
