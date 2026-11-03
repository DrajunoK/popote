/// Modèles du domaine (spec §5.4). Sans dépendance Flutter, sérialisables en JSON.
library;

T? enumByName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Nombre de jours depuis l'epoch, insensible aux changements d'heure.
int dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

// ---------------------------------------------------------------------------
// Catégories (F-REC-10)
// ---------------------------------------------------------------------------

enum Protein {
  beef('Bœuf / veau', 'Bœuf'),
  pork('Porc', 'Porc'),
  poultry('Volaille', 'Volaille'),
  fish('Poisson & fruits de mer', 'Poisson'),
  eggs('Œufs', 'Œufs'),
  veg('Végétarien', 'Végé'),
  vegan('Vegan', 'Vegan');

  const Protein(this.label, this.short);
  final String label;
  final String short;
  bool get isRedMeat => this == beef;
  bool get isMeatless => this == veg || this == vegan;
}

enum Base {
  pasta('Pâtes'),
  rice('Riz'),
  potato('Pommes de terre'),
  dough('Pain / pâte'),
  legumes('Légumineuses'),
  cereals('Céréales'),
  veg('Légumes seuls');

  const Base(this.label);
  final String label;
}

enum DishType {
  gratin('Gratin / four'),
  stew('Mijoté'),
  stirfry('Poêlée / wok'),
  soup('Soupe'),
  salad('Salade'),
  tart('Tarte / quiche'),
  grill('Grillade'),
  cold('Plat froid');

  const DishType(this.label);
  final String label;
}

enum Effort {
  quick('Rapide'),
  normal('Normal'),
  long('Long');

  const Effort(this.label);
  final String label;
}

enum Season {
  all('Toute l’année'),
  springSummer('Printemps-été'),
  autumnWinter('Automne-hiver');

  const Season(this.label);
  final String label;

  bool matches(DateTime d) {
    if (this == Season.all) return true;
    final warm = d.month >= 4 && d.month <= 9;
    return this == Season.springSummer ? warm : !warm;
  }
}

enum Aisle {
  fruitsVeg('Fruits & légumes'),
  fresh('Frais'),
  grocery('Épicerie'),
  frozen('Surgelés'),
  drinks('Boissons'),
  hygiene('Hygiène'),
  home('Maison'),
  other('Autre');

  const Aisle(this.label);
  final String label;
}

enum SlotKind {
  breakfast('Petit-déj'),
  lunch('Midi'),
  snack('Goûter'),
  dinner('Dîner');

  const SlotKind(this.label);
  final String label;
}

enum Role {
  admin('Admin'),
  member('Membre'),
  viewer('Lecteur');

  const Role(this.label);
  final String label;
}

enum PeriodType {
  week('Planning à la semaine'),
  stay('Weekend / séjour'),
  year('Planning annuel');

  const PeriodType(this.label);
  final String label;
}

// ---------------------------------------------------------------------------
// Recettes
// ---------------------------------------------------------------------------

class RecipeIngredient {
  const RecipeIngredient(this.name, this.qty, this.unit, this.aisle);

  final String name;
  final double qty;

  /// 'g', 'kg', 'ml', 'cl', 'l', 'pièce', 'c. à soupe', 'c. à café' ou '' (au goût).
  final String unit;
  final Aisle aisle;

  Map<String, dynamic> toJson() => {'n': name, 'q': qty, 'u': unit, 'a': aisle.name};

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        j['n'] as String,
        (j['q'] as num).toDouble(),
        j['u'] as String,
        enumByName(Aisle.values, j['a']) ?? Aisle.other,
      );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    this.servings = 4,
    this.prepMin = 0,
    this.cookMin = 0,
    this.ingredients = const [],
    this.steps = const [],
    this.tags = const [],
    this.protein,
    this.base,
    this.dish,
    this.season = Season.all,
    this.cuisine,
    this.kidFriendly = false,
    this.shared = true,
    this.notes,
    this.effortOverride,
    this.photoPath,
    this.groupId,
  });

  final String id;
  final String title;
  final int servings;
  final int prepMin;
  final int cookMin;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<String> tags;
  final Protein? protein;
  final Base? base;
  final DishType? dish;
  final Season season;
  final String? cuisine;
  final bool kidFriendly;

  /// F-REC-05 : partagée au groupe (true) ou personnelle (false).
  final bool shared;
  final String? notes;
  final Effort? effortOverride;

  /// Photo choisie par l'utilisateur (fichier local) ; sinon on affiche un emoji.
  final String? photoPath;

  /// Groupe propriétaire : c'est lui qui voit la recette et la synchronise.
  final String? groupId;

  /// Copie avec un autre identifiant / groupe (recettes de démarrage propres à chaque groupe).
  Recipe relocated({required String id, required String groupId}) => Recipe(
        id: id,
        title: title,
        servings: servings,
        prepMin: prepMin,
        cookMin: cookMin,
        ingredients: ingredients,
        steps: steps,
        tags: tags,
        protein: protein,
        base: base,
        dish: dish,
        season: season,
        cuisine: cuisine,
        kidFriendly: kidFriendly,
        shared: shared,
        notes: notes,
        effortOverride: effortOverride,
        photoPath: photoPath,
        groupId: groupId,
      );

  /// F-REC-03 : un repas « simple » n'a que un titre.
  bool get isSimple => ingredients.isEmpty;
  int get totalMin => prepMin + cookMin;
  bool get isCategorized => protein != null && base != null;

  Effort get effort =>
      effortOverride ?? (totalMin <= 30 ? Effort.quick : (totalMin <= 75 ? Effort.normal : Effort.long));

  /// Étiquettes utilisées par les filtres de la bibliothèque.
  Set<String> get allTags => {
        ...tags,
        if (protein?.isMeatless ?? false) 'Végétarien',
        if (effort == Effort.quick) 'Rapide',
        if (kidFriendly) 'Enfants',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'servings': servings,
        'prep': prepMin,
        'cook': cookMin,
        'ings': ingredients.map((e) => e.toJson()).toList(),
        'steps': steps,
        'tags': tags,
        'protein': protein?.name,
        'base': base?.name,
        'dish': dish?.name,
        'season': season.name,
        'cuisine': cuisine,
        'kid': kidFriendly,
        'shared': shared,
        'notes': notes,
        'effort': effortOverride?.name,
        'photo': photoPath,
        'gid': groupId,
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        title: j['title'] as String,
        servings: j['servings'] as int,
        prepMin: j['prep'] as int,
        cookMin: j['cook'] as int,
        ingredients: (j['ings'] as List).map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>)).toList(),
        steps: (j['steps'] as List).cast<String>(),
        tags: (j['tags'] as List).cast<String>(),
        protein: enumByName(Protein.values, j['protein']),
        base: enumByName(Base.values, j['base']),
        dish: enumByName(DishType.values, j['dish']),
        season: enumByName(Season.values, j['season']) ?? Season.all,
        cuisine: j['cuisine'] as String?,
        kidFriendly: j['kid'] as bool? ?? false,
        shared: j['shared'] as bool? ?? true,
        notes: j['notes'] as String?,
        effortOverride: enumByName(Effort.values, j['effort']),
        photoPath: j['photo'] as String?,
        groupId: j['gid'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Planning
// ---------------------------------------------------------------------------

class PlanEntry {
  const PlanEntry({
    required this.id,
    required this.groupId,
    required this.date,
    required this.slot,
    this.recipeId,
    this.freeText,
    this.guests = 4,
    this.note,
  });

  final String id;
  final String groupId;
  final DateTime date;
  final SlotKind slot;
  final String? recipeId;

  /// Note libre (« Restes », « Au resto »…) quand aucune recette n'est liée (F-PLN-06).
  final String? freeText;
  final int guests;
  final String? note;

  PlanEntry copyWith({DateTime? date, SlotKind? slot, int? guests, String? note}) => PlanEntry(
        id: id,
        groupId: groupId,
        date: date ?? this.date,
        slot: slot ?? this.slot,
        recipeId: recipeId,
        freeText: freeText,
        guests: guests ?? this.guests,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'g': groupId,
        'd': dayKey(date),
        's': slot.name,
        'r': recipeId,
        't': freeText,
        'n': guests,
        'note': note,
      };

  factory PlanEntry.fromJson(Map<String, dynamic> j) => PlanEntry(
        id: j['id'] as String,
        groupId: j['g'] as String,
        date: parseDay(j['d'] as String),
        slot: enumByName(SlotKind.values, j['s']) ?? SlotKind.dinner,
        recipeId: j['r'] as String?,
        freeText: j['t'] as String?,
        guests: j['n'] as int? ?? 4,
        note: j['note'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Liste de courses
// ---------------------------------------------------------------------------

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.groupId,
    required this.label,
    required this.qty,
    required this.unit,
    required this.aisle,
    required this.manual,
    this.sources = const [],
    this.checked = false,
    this.firstUse,
  });

  final String id;
  final String groupId;
  final String label;
  final double qty;
  final String unit;
  final Aisle aisle;

  /// Premier jour planifié où l'article sert ; permet de signaler un produit frais à acheter plus tard.
  final DateTime? firstUse;

  /// `true` : ajout libre, jamais supprimé par une régénération (F-SHP-07).
  final bool manual;

  /// Titres des recettes qui ont généré l'article (F-SHP-06).
  final List<String> sources;
  final bool checked;

  String get key => '${label.toLowerCase()}|$unit';

  /// Produit frais dont le premier repas tombe au moins [days] jours après le début de la période.
  bool buyLater(DateTime from, {int days = 4}) =>
      firstUse != null &&
      (aisle == Aisle.fresh || aisle == Aisle.fruitsVeg) &&
      firstUse!.difference(from).inDays >= days;

  ShoppingItem copyWith({double? qty, bool? checked, String? unit}) => ShoppingItem(
        id: id,
        groupId: groupId,
        label: label,
        qty: qty ?? this.qty,
        unit: unit ?? this.unit,
        aisle: aisle,
        manual: manual,
        sources: sources,
        checked: checked ?? this.checked,
        firstUse: firstUse,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'g': groupId,
        'l': label,
        'q': qty,
        'u': unit,
        'a': aisle.name,
        'm': manual,
        's': sources,
        'c': checked,
        if (firstUse != null) 'd': dayKey(firstUse!),
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> j) => ShoppingItem(
        id: j['id'] as String,
        groupId: j['g'] as String,
        label: j['l'] as String,
        qty: (j['q'] as num).toDouble(),
        unit: j['u'] as String,
        aisle: enumByName(Aisle.values, j['a']) ?? Aisle.other,
        manual: j['m'] as bool,
        sources: (j['s'] as List).cast<String>(),
        checked: j['c'] as bool,
        firstUse: j['d'] == null ? null : parseDay(j['d'] as String),
      );
}

class ShoppingMeta {
  const ShoppingMeta({required this.from, required this.to, required this.meals});

  final DateTime from;
  final DateTime to;
  final int meals;

  Map<String, dynamic> toJson() => {'f': dayKey(from), 't': dayKey(to), 'm': meals};

  factory ShoppingMeta.fromJson(Map<String, dynamic> j) =>
      ShoppingMeta(from: parseDay(j['f'] as String), to: parseDay(j['t'] as String), meals: j['m'] as int);
}

// ---------------------------------------------------------------------------
// Groupes
// ---------------------------------------------------------------------------

class Member {
  const Member(this.name, this.role, {this.isMe = false, this.userId, this.email});

  final String name;
  final Role role;
  final bool isMe;

  /// Identifiant du compte (Supabase) ; absent tant que le groupe n'est pas synchronisé.
  final String? userId;
  final String? email;

  Map<String, dynamic> toJson() => {'n': name, 'r': role.name, 'me': isMe, 'u': userId, 'e': email};

  factory Member.fromJson(Map<String, dynamic> j) => Member(
        j['n'] as String,
        enumByName(Role.values, j['r']) ?? Role.member,
        isMe: j['me'] as bool? ?? false,
        userId: j['u'] as String?,
        email: j['e'] as String?,
      );
}

/// Règles du bouton magique (§3.8), configurables par groupe.
class PlannerRules {
  const PlannerRules({
    this.vary = true,
    this.veg = true,
    this.fish = true,
    this.quick = true,
    this.season = true,
    this.minVeg = 2,
    this.minFish = 1,
    this.maxRedMeat = 2,
    this.historyDays = 14,
    this.favoriteWeight = 2,
    this.keepExisting = true,
  });

  /// Varier protéines, bases et types de plats.
  final bool vary;

  /// Minimum de repas végétariens.
  final bool veg;

  /// Minimum de repas poisson.
  final bool fish;

  /// Pas de recette « Long » en semaine.
  final bool quick;
  final bool season;
  final int minVeg;
  final int minFish;
  final int maxRedMeat;
  final int historyDays;
  final double favoriteWeight;
  final bool keepExisting;

  PlannerRules copyWith({bool? vary, bool? veg, bool? fish, bool? quick, bool? season, bool? keepExisting}) =>
      PlannerRules(
        vary: vary ?? this.vary,
        veg: veg ?? this.veg,
        fish: fish ?? this.fish,
        quick: quick ?? this.quick,
        season: season ?? this.season,
        minVeg: minVeg,
        minFish: minFish,
        maxRedMeat: maxRedMeat,
        historyDays: historyDays,
        favoriteWeight: favoriteWeight,
        keepExisting: keepExisting ?? this.keepExisting,
      );

  Map<String, dynamic> toJson() => {
        'vary': vary,
        'veg': veg,
        'fish': fish,
        'quick': quick,
        'season': season,
        'minVeg': minVeg,
        'minFish': minFish,
        'maxRed': maxRedMeat,
        'hist': historyDays,
        'fav': favoriteWeight,
        'keep': keepExisting,
      };

  factory PlannerRules.fromJson(Map<String, dynamic> j) => PlannerRules(
        vary: j['vary'] as bool? ?? true,
        veg: j['veg'] as bool? ?? true,
        fish: j['fish'] as bool? ?? true,
        quick: j['quick'] as bool? ?? true,
        season: j['season'] as bool? ?? true,
        minVeg: j['minVeg'] as int? ?? 2,
        minFish: j['minFish'] as int? ?? 1,
        maxRedMeat: j['maxRed'] as int? ?? 2,
        historyDays: j['hist'] as int? ?? 14,
        favoriteWeight: (j['fav'] as num?)?.toDouble() ?? 2,
        keepExisting: j['keep'] as bool? ?? true,
      );
}

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.color,
    required this.period,
    required this.members,
    this.personal = false,
    this.startDate,
    this.endDate,
    this.slots = const [SlotKind.lunch, SlotKind.dinner],
    this.rules = const PlannerRules(),
    this.archived = false,
  });

  final String id;
  final String name;

  /// Couleur ARGB (pastille du groupe).
  final int color;
  final PeriodType period;
  final List<Member> members;
  final bool personal;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<SlotKind> slots;
  final PlannerRules rules;
  final bool archived;

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  int get size => members.length;

  Group copyWith({
    String? name,
    int? color,
    List<Member>? members,
    PlannerRules? rules,
    List<SlotKind>? slots,
    bool? archived,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        period: period,
        members: members ?? this.members,
        personal: personal,
        startDate: startDate,
        endDate: endDate,
        slots: slots ?? this.slots,
        rules: rules ?? this.rules,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'period': period.name,
        'members': members.map((m) => m.toJson()).toList(),
        'personal': personal,
        'start': startDate == null ? null : dayKey(startDate!),
        'end': endDate == null ? null : dayKey(endDate!),
        'slots': slots.map((s) => s.name).toList(),
        'rules': rules.toJson(),
        'archived': archived,
      };

  /// Réglages synchronisés (colonne `groups.settings`) : tout sauf identité et membres.
  Map<String, dynamic> settingsJson() => {
        'period': period.name,
        'start': startDate == null ? null : dayKey(startDate!),
        'end': endDate == null ? null : dayKey(endDate!),
        'slots': slots.map((s) => s.name).toList(),
        'rules': rules.toJson(),
        'archived': archived,
      };

  /// Reconstruit un groupe depuis une ligne distante ; [members] vient de `group_members`.
  factory Group.fromRemote({
    required String id,
    required String name,
    required int color,
    required bool personal,
    required Map<String, dynamic> settings,
    required List<Member> members,
  }) =>
      Group(
        id: id,
        name: name,
        color: color,
        period: enumByName(PeriodType.values, settings['period']) ?? PeriodType.week,
        members: members,
        personal: personal,
        startDate: settings['start'] == null ? null : parseDay(settings['start'] as String),
        endDate: settings['end'] == null ? null : parseDay(settings['end'] as String),
        slots: ((settings['slots'] as List?) ?? const ['lunch', 'dinner'])
            .map((s) => enumByName(SlotKind.values, s))
            .whereType<SlotKind>()
            .toList(),
        rules: settings['rules'] == null
            ? const PlannerRules()
            : PlannerRules.fromJson(settings['rules'] as Map<String, dynamic>),
        archived: settings['archived'] as bool? ?? false,
      );

  factory Group.fromJson(Map<String, dynamic> j) => Group(
        id: j['id'] as String,
        name: j['name'] as String,
        color: j['color'] as int,
        period: enumByName(PeriodType.values, j['period']) ?? PeriodType.week,
        members: (j['members'] as List).map((e) => Member.fromJson(e as Map<String, dynamic>)).toList(),
        personal: j['personal'] as bool? ?? false,
        startDate: j['start'] == null ? null : parseDay(j['start'] as String),
        endDate: j['end'] == null ? null : parseDay(j['end'] as String),
        slots: (j['slots'] as List).map((s) => enumByName(SlotKind.values, s)).whereType<SlotKind>().toList(),
        rules: PlannerRules.fromJson(j['rules'] as Map<String, dynamic>),
        archived: j['archived'] as bool? ?? false,
      );
}

// ---------------------------------------------------------------------------
// État global
// ---------------------------------------------------------------------------

class UserProfile {
  const UserProfile({required this.name, required this.email});

  final String name;
  final String email;

  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

  Map<String, dynamic> toJson() => {'name': name, 'email': email};

  factory UserProfile.fromJson(Map<String, dynamic> j) =>
      UserProfile(name: j['name'] as String, email: j['email'] as String);
}

class AppData {
  const AppData({
    required this.user,
    required this.recipes,
    required this.favorites,
    required this.groups,
    required this.currentGroupId,
    required this.entries,
    required this.shopping,
    required this.lists,
    required this.pantry,
    required this.themeKey,
    required this.remindSunday,
  });

  final UserProfile? user;
  final List<Recipe> recipes;
  final Set<String> favorites;
  final List<Group> groups;
  final String currentGroupId;
  final List<PlanEntry> entries;
  final List<ShoppingItem> shopping;
  final Map<String, ShoppingMeta> lists;

  /// Ingrédients « déjà à la maison », exclus de la génération (F-SHP-11), en minuscules.
  final Set<String> pantry;
  final String themeKey;
  final bool remindSunday;

  Group get currentGroup => groups.firstWhere((g) => g.id == currentGroupId, orElse: () => groups.first);

  AppData copyWith({
    Object? user = _keep,
    List<Recipe>? recipes,
    Set<String>? favorites,
    List<Group>? groups,
    String? currentGroupId,
    List<PlanEntry>? entries,
    List<ShoppingItem>? shopping,
    Map<String, ShoppingMeta>? lists,
    Set<String>? pantry,
    String? themeKey,
    bool? remindSunday,
  }) =>
      AppData(
        user: identical(user, _keep) ? this.user : user as UserProfile?,
        recipes: recipes ?? this.recipes,
        favorites: favorites ?? this.favorites,
        groups: groups ?? this.groups,
        currentGroupId: currentGroupId ?? this.currentGroupId,
        entries: entries ?? this.entries,
        shopping: shopping ?? this.shopping,
        lists: lists ?? this.lists,
        pantry: pantry ?? this.pantry,
        themeKey: themeKey ?? this.themeKey,
        remindSunday: remindSunday ?? this.remindSunday,
      );

  Map<String, dynamic> toJson() => {
        'user': user?.toJson(),
        'recipes': recipes.map((e) => e.toJson()).toList(),
        'favorites': favorites.toList(),
        'groups': groups.map((e) => e.toJson()).toList(),
        'current': currentGroupId,
        'entries': entries.map((e) => e.toJson()).toList(),
        'shopping': shopping.map((e) => e.toJson()).toList(),
        'lists': lists.map((k, v) => MapEntry(k, v.toJson())),
        'pantry': pantry.toList(),
        'theme': themeKey,
        'remind': remindSunday,
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        user: j['user'] == null ? null : UserProfile.fromJson(j['user'] as Map<String, dynamic>),
        recipes: (j['recipes'] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList(),
        favorites: (j['favorites'] as List).cast<String>().toSet(),
        groups: (j['groups'] as List).map((e) => Group.fromJson(e as Map<String, dynamic>)).toList(),
        currentGroupId: j['current'] as String,
        entries: (j['entries'] as List).map((e) => PlanEntry.fromJson(e as Map<String, dynamic>)).toList(),
        shopping: (j['shopping'] as List).map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>)).toList(),
        lists: (j['lists'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, ShoppingMeta.fromJson(v as Map<String, dynamic>))),
        pantry: (j['pantry'] as List).cast<String>().toSet(),
        themeKey: j['theme'] as String? ?? 'nuit',
        remindSunday: j['remind'] as bool? ?? true,
      );
}

const Object _keep = Object();
