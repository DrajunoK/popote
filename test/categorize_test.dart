import 'package:flutter_test/flutter_test.dart';
import 'package:popote/data/models.dart';
import 'package:popote/domain/categorize.dart';

void main() {
  test('suggère protéine et base depuis les ingrédients', () {
    expect(suggestProtein(['Lardons', 'Œufs']), Protein.pork);
    expect(suggestBase(['Spaghetti', 'Lardons']), Base.pasta);
    expect(suggestProtein(['Tomates', 'Courgettes']), Protein.veg);
    expect(suggestProtein([]), isNull);
  });
}
