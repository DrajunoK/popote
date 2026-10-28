import '../data/models.dart';

/// Emoji associé à un repas, déduit du titre puis de la catégorie.
/// Sert de visuel tant que l'utilisateur n'a pas ajouté sa propre photo.
const _titleKeywords = <String, List<String>>{
  '🍝': ['spaghetti', 'pâtes', 'pates', 'carbonara', 'bolognaise', 'tagliatelle', 'penne', 'lasagne', 'macaroni'],
  '🍕': ['pizza'],
  '🍔': ['burger', 'hamburger'],
  '🌮': ['tacos', 'tortilla', 'wrap', 'fajita', 'burrito'],
  '🥧': ['quiche', 'tarte', 'tourte', 'flammekueche'],
  '🍲': ['soupe', 'velouté', 'veloute', 'potage', 'pot-au-feu', 'blanquette', 'bourguignon', 'ragoût', 'ragout', 'daube', 'cassoulet', 'chili', 'curry', 'tajine', 'couscous', 'dahl', 'dal'],
  '🥗': ['salade', 'taboulé', 'taboule'],
  '🍚': ['riz', 'risotto', 'paëlla', 'paella'],
  '🍟': ['frites'],
  '🥔': ['gratin', 'dauphinois', 'purée', 'puree', 'hachis', 'parmentier', 'pomme de terre', 'raclette', 'tartiflette'],
  '🍗': ['poulet', 'volaille', 'dinde', 'cuisse'],
  '🥩': ['steak', 'bœuf', 'boeuf', 'rôti', 'roti', 'côte', 'cote', 'entrecôte', 'veau'],
  '🌭': ['saucisse', 'knack'],
  '🐟': ['saumon', 'cabillaud', 'colin', 'thon', 'poisson', 'dorade', 'truite'],
  '🦐': ['crevette', 'moule', 'fruits de mer'],
  '🍳': ['omelette', 'œuf', 'oeuf', 'frittata', 'shakshuka'],
  '🥞': ['crêpe', 'crepe', 'galette', 'pancake'],
  '🍜': ['nouilles', 'wok', 'ramen', 'pad thaï', 'pad thai'],
  '🧀': ['croque', 'fondue', 'fromage'],
  '🥦': ['légume', 'legume', 'ratatouille', 'courgette', 'brocoli', 'chou'],
  '🫘': ['lentille', 'pois chiche', 'haricot'],
};

String recipeEmoji(Recipe r) {
  final title = r.title.toLowerCase();
  for (final e in _titleKeywords.entries) {
    if (e.value.any(title.contains)) return e.key;
  }
  switch (r.dish) {
    case DishType.soup:
    case DishType.stew:
      return '🍲';
    case DishType.salad:
    case DishType.cold:
      return '🥗';
    case DishType.tart:
      return '🥧';
    case DishType.gratin:
      return '🥔';
    case DishType.stirfry:
      return '🍜';
    case DishType.grill:
      return '🥩';
    case null:
      break;
  }
  return switch (r.protein) {
    Protein.beef => '🥩',
    Protein.pork => '🍖',
    Protein.poultry => '🍗',
    Protein.fish => '🐟',
    Protein.eggs => '🍳',
    Protein.veg || Protein.vegan => '🥦',
    null => '🍽️',
  };
}
