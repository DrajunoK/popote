import '../data/models.dart';

/// Suggestion automatique de la protéine et de la base à partir des ingrédients
/// (F-REC-10 : « lardons » → Porc, « spaghetti » → Pâtes).
const _proteinKeywords = <Protein, List<String>>{
  Protein.pork: ['lardon', 'jambon', 'saucisse', 'porc', 'chorizo', 'bacon', 'reblochon'],
  Protein.beef: ['bœuf', 'boeuf', 'veau', 'viande hachée', 'steak'],
  Protein.poultry: ['poulet', 'dinde', 'canard', 'volaille'],
  Protein.fish: ['saumon', 'cabillaud', 'thon', 'poisson', 'moule', 'crevette', 'colin'],
  Protein.eggs: ['œuf', 'oeuf'],
};

const _baseKeywords = <Base, List<String>>{
  Base.pasta: ['spaghetti', 'pâtes', 'penne', 'tagliatelle', 'lasagne', 'macaroni', 'coquillette'],
  Base.rice: ['riz'],
  Base.potato: ['pomme de terre', 'pommes de terre', 'patate'],
  Base.dough: ['pâte brisée', 'pâte feuilletée', 'pain', 'tortilla', 'farine', 'pizza'],
  Base.legumes: ['lentille', 'pois chiche', 'haricot', 'fève'],
  Base.cereals: ['semoule', 'quinoa', 'boulgour', 'blé'],
};

/// Les ingrédients de viande l'emportent sur le poisson, les œufs puis le végétarien.
const _proteinPriority = [Protein.beef, Protein.pork, Protein.poultry, Protein.fish, Protein.eggs];

Protein? suggestProtein(Iterable<String> ingredientNames) {
  final names = ingredientNames.map((n) => n.toLowerCase()).toList();
  if (names.isEmpty) return null;
  for (final p in _proteinPriority) {
    if (names.any((n) => _proteinKeywords[p]!.any(n.contains))) return p;
  }
  return Protein.veg;
}

Base? suggestBase(Iterable<String> ingredientNames) {
  final names = ingredientNames.map((n) => n.toLowerCase()).toList();
  if (names.isEmpty) return null;
  for (final entry in _baseKeywords.entries) {
    if (names.any((n) => entry.value.any(n.contains))) return entry.key;
  }
  return Base.veg;
}
