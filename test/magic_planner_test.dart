import 'package:flutter_test/flutter_test.dart';
import 'package:popote/data/models.dart';
import 'package:popote/data/seed.dart';
import 'package:popote/domain/magic_planner.dart';

final monday = DateTime(2026, 10, 26);
final today = DateTime(2026, 10, 27);

List<PlanSlot> week() => [for (var i = 0; i < 7; i++) PlanSlot(monday.add(Duration(days: i)), SlotKind.dinner)];

MagicResult run(int seed, {PlannerRules rules = const PlannerRules(), Map<int, Recipe> fixed = const {}}) => planMagic(
      slots: week(),
      candidates: starterRecipes(),
      fixed: fixed,
      lastCooked: const {},
      favorites: const {'r_lasagnes', 'r_quiche'},
      rules: rules,
      seed: seed,
      today: today,
    );

void main() {
  test('remplit les 7 dîners sans doublon de recette', () {
    final r = run(1);
    expect(r.picks, hasLength(7));
    expect(r.picks.values.map((e) => e.id).toSet(), hasLength(7));
  });

  test('même graine → même proposition ; autre graine → autre proposition', () {
    List<String> ids(MagicResult r) => (r.picks.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => e.value.id)
        .toList();
    expect(ids(run(42)), ids(run(42)));
    final others = {for (var s = 0; s < 20; s++) ids(run(s)).join(',')};
    expect(others.length, greaterThan(1));
  });

  test('jamais la même protéine deux repas de suite, sur plusieurs graines', () {
    for (var seed = 0; seed < 30; seed++) {
      final picks = run(seed).picks;
      final ords = picks.keys.toList()..sort();
      for (var i = 1; i < ords.length; i++) {
        expect(picks[ords[i]]!.protein, isNot(picks[ords[i - 1]]!.protein), reason: 'seed $seed');
      }
    }
  });

  test('respecte les quotas : ≥ 2 végé, ≥ 1 poisson, ≤ 2 viande rouge', () {
    for (var seed = 0; seed < 30; seed++) {
      final all = run(seed).picks.values.toList();
      expect(all.where((r) => r.protein!.isMeatless).length, greaterThanOrEqualTo(2), reason: 'seed $seed');
      expect(all.where((r) => r.protein == Protein.fish).length, greaterThanOrEqualTo(1), reason: 'seed $seed');
      expect(all.where((r) => r.protein!.isRedMeat).length, lessThanOrEqualTo(2), reason: 'seed $seed');
    }
  });

  test('pas de recette « Long » en semaine', () {
    for (var seed = 0; seed < 20; seed++) {
      for (final e in run(seed).picks.entries) {
        final slot = week().firstWhere((s) => s.ord == e.key);
        if (slot.isWeekday) expect(e.value.effort, isNot(Effort.long), reason: 'seed $seed');
      }
    }
  });

  test('les repas verrouillés servent de contraintes', () {
    final lasagnes = starterRecipes().firstWhere((r) => r.id == 'r_lasagnes');
    final monday0 = week().first;
    final slots = week().skip(1).toList();
    final r = planMagic(
      slots: slots,
      candidates: starterRecipes(),
      fixed: {monday0.ord: lasagnes},
      lastCooked: const {},
      favorites: const {},
      rules: const PlannerRules(),
      seed: 3,
      today: today,
    );
    expect(r.picks.values.any((e) => e.id == lasagnes.id), isFalse);
    final tuesday = r.picks[slots.first.ord]!;
    expect(tuesday.protein, isNot(Protein.beef));
    expect(tuesday.base, isNot(Base.pasta));
  });

  test('bibliothèque trop petite : avertit au lieu de planter', () {
    final r = planMagic(
      slots: week(),
      candidates: starterRecipes().take(3).toList(),
      fixed: const {},
      lastCooked: const {},
      favorites: const {},
      rules: const PlannerRules(),
      seed: 1,
      today: today,
    );
    expect(r.picks.length, lessThanOrEqualTo(3));
    expect(r.warnings, isNotEmpty);
  });
}
