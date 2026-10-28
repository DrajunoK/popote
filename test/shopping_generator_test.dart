import 'package:flutter_test/flutter_test.dart';
import 'package:popote/core/format.dart';
import 'package:popote/data/models.dart';
import 'package:popote/domain/shopping_generator.dart';

Recipe recipe(String id, int servings, List<RecipeIngredient> ings) =>
    Recipe(id: id, title: 'R $id', servings: servings, ingredients: ings, protein: Protein.veg, base: Base.veg);

PlanEntry entry(String id, String recipeId, {int guests = 4, int day = 27}) => PlanEntry(
      id: id,
      groupId: 'g',
      date: DateTime(2026, 10, day),
      slot: SlotKind.dinner,
      recipeId: recipeId,
      guests: guests,
    );

int _n = 0;
String _id() => 'i${_n++}';

List<ShoppingItem> gen(List<PlanEntry> entries, Map<String, Recipe> recipes,
        {Set<String> pantry = const {}, List<ShoppingItem> existing = const []}) =>
    generateShopping(
      groupId: 'g',
      entries: entries,
      recipes: recipes,
      pantry: pantry,
      existing: existing,
      newId: _id,
    );

void main() {
  const flour = RecipeIngredient('Farine', 200, 'g', Aisle.grocery);

  test('agrège les ingrédients identiques (2 × 200 g → 400 g)', () {
    final recipes = {'a': recipe('a', 4, [flour]), 'b': recipe('b', 4, [flour])};
    final items = gen([entry('1', 'a'), entry('2', 'b', day: 28)], recipes);
    expect(items, hasLength(1));
    expect(items.single.qty, 400);
    expect(items.single.sources, ['R a', 'R b']);
  });

  test('convertit les unités compatibles (g + kg, cl + l)', () {
    final recipes = {
      'a': recipe('a', 4, [flour, const RecipeIngredient('Lait', 50, 'cl', Aisle.fresh)]),
      'b': recipe('b', 4, [
        const RecipeIngredient('Farine', 0.5, 'kg', Aisle.grocery),
        const RecipeIngredient('Lait', 0.5, 'l', Aisle.fresh),
      ]),
    };
    final items = gen([entry('1', 'a'), entry('2', 'b', day: 28)], recipes);
    final byLabel = {for (final i in items) i.label: i};
    expect(byLabel['Farine']!.qty, 700);
    expect(formatQty(byLabel['Farine']!.qty, byLabel['Farine']!.unit), '700 g');
    expect(byLabel['Lait']!.qty, 1000);
    expect(formatQty(byLabel['Lait']!.qty, byLabel['Lait']!.unit), '1 l');
  });

  test('adapte les quantités au nombre de convives', () {
    final recipes = {'a': recipe('a', 4, [flour])};
    final items = gen([entry('1', 'a', guests: 8)], recipes);
    expect(items.single.qty, 400);
  });

  test('arrondit les pièces au supérieur (0,4 oignon → 1)', () {
    final recipes = {
      'a': recipe('a', 5, [const RecipeIngredient('Oignon', 1, 'pièce', Aisle.fruitsVeg)]),
    };
    final items = gen([entry('1', 'a', guests: 2)], recipes);
    expect(items.single.qty, 1);
  });

  test('exclut le placard', () {
    final recipes = {'a': recipe('a', 4, [flour, const RecipeIngredient('Sel', 5, 'g', Aisle.grocery)])};
    final items = gen([entry('1', 'a')], recipes, pantry: {'sel'});
    expect(items.map((i) => i.label), ['Farine']);
  });

  test('ignore les repas simples et les notes libres', () {
    final recipes = {'s': const Recipe(id: 's', title: 'Pizza')};
    final items = gen([entry('1', 's')], recipes);
    expect(items, isEmpty);
  });

  test('la régénération conserve les ajouts manuels et les cases cochées', () {
    final recipes = {'a': recipe('a', 4, [flour])};
    final first = gen([entry('1', 'a')], recipes);
    const lessive = ShoppingItem(
      id: 'm1',
      groupId: 'g',
      label: 'Lessive',
      qty: 1,
      unit: '',
      aisle: Aisle.home,
      manual: true,
    );
    final existing = [first.single.copyWith(checked: true), lessive];

    final again = gen([entry('1', 'a')], recipes, existing: existing);
    expect(again.map((i) => i.label), containsAll(['Farine', 'Lessive']));
    expect(again.firstWhere((i) => i.label == 'Farine').checked, isTrue);
    expect(again.firstWhere((i) => i.label == 'Farine').id, first.single.id);
  });

  test('formatQty', () {
    expect(formatQty(1200, 'g'), '1,2 kg');
    expect(formatQty(400, 'ml'), '40 cl');
    expect(formatQty(6, 'pièce'), '6');
    expect(formatQty(2, 'c. à soupe'), '2 c. à soupe');
  });
}
