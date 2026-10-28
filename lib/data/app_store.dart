import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shopping_generator.dart' as gen;
import 'models.dart';
import 'seed.dart';

const _storageKey = 'popote.v2';

/// Surchargé dans `main()` avec l'instance initialisée.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider'));

final appStoreProvider = NotifierProvider<AppStore, AppData>(AppStore.new);

/// Source de vérité locale (local-first, spec §5.3). Persistée en JSON dans
/// SharedPreferences ; l'interface publique est celle qu'exposera plus tard le
/// dépôt Drift + Supabase.
class AppStore extends Notifier<AppData> {
  int _seq = 0;

  @override
  AppData build() {
    final raw = ref.read(prefsProvider).getString(_storageKey);
    if (raw != null) {
      try {
        return AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Données corrompues ou ancien format : on repart des données de démarrage.
      }
    }
    return seedData();
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  void _set(AppData d) {
    state = d;
    ref.read(prefsProvider).setString(_storageKey, jsonEncode(d.toJson()));
  }

  // --- Compte ------------------------------------------------------------

  void signIn(UserProfile user) => _set(state.copyWith(user: user));

  /// Déconnexion : les données appartiennent au compte (elles sont sur le serveur), on repart d'un
  /// état vierge pour qu'un autre compte sur le même appareil ne les récupère pas.
  void signOut() => _set(seedData());

  /// Point d'entrée de la synchronisation : applique une transformation de l'état complet.
  void apply(AppData Function(AppData) f) => _set(f(state));

  /// F-AUTH-03 : supprime le compte et toutes les données locales.
  void deleteAccount() => _set(seedData());

  // --- Réglages ----------------------------------------------------------

  void setTheme(String key) => _set(state.copyWith(themeKey: key));

  void setRemind(bool on) => _set(state.copyWith(remindSunday: on));

  // --- Groupes -----------------------------------------------------------

  void selectGroup(String id) => _set(state.copyWith(currentGroupId: id));

  String createGroup(String name, PeriodType period, int color, {DateTime? start, DateTime? end}) {
    final id = 'g_${randomId()}';
    final me = state.user?.name ?? 'Moi';
    final g = Group(
      id: id,
      name: name,
      color: color,
      period: period,
      startDate: start,
      endDate: end,
      members: [Member(me, Role.admin, isMe: true)],
    );
    _set(state.copyWith(groups: [...state.groups, g], currentGroupId: id));
    return id;
  }

  /// Retire un groupe et tout ce qui lui appartient de cet appareil.
  void removeGroup(String id) {
    final groups = state.groups.where((g) => g.id != id).toList();
    if (groups.isEmpty) return;
    _set(state.copyWith(
      groups: groups,
      currentGroupId: state.currentGroupId == id ? groups.first.id : state.currentGroupId,
      recipes: state.recipes.where((r) => r.groupId != id).toList(),
      entries: state.entries.where((e) => e.groupId != id).toList(),
      shopping: state.shopping.where((i) => i.groupId != id).toList(),
      lists: {...state.lists}..remove(id),
    ));
  }

  void renameGroup(String id, String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _set(state.copyWith(groups: [for (final g in state.groups) g.id == id ? g.copyWith(name: clean) : g]));
  }

  void updateRules(String groupId, PlannerRules rules) => _set(state.copyWith(
        groups: [for (final g in state.groups) g.id == groupId ? g.copyWith(rules: rules) : g],
      ));

  void setSlots(String groupId, List<SlotKind> slots) => _set(state.copyWith(
        groups: [for (final g in state.groups) g.id == groupId ? g.copyWith(slots: slots) : g],
      ));

  // --- Recettes ----------------------------------------------------------

  void toggleFavorite(String recipeId) {
    final f = {...state.favorites};
    if (!f.remove(recipeId)) f.add(recipeId);
    _set(state.copyWith(favorites: f));
  }

  /// Crée ou remplace une recette (même `id`).
  void upsertRecipe(Recipe input) {
    final list = [...state.recipes];
    final i = list.indexWhere((x) => x.id == input.id);
    // Une recette appartient à un groupe : celui d'origine, sinon le groupe courant.
    final r = input.groupId != null
        ? input
        : input.relocated(id: input.id, groupId: i >= 0 ? (list[i].groupId ?? state.currentGroupId) : state.currentGroupId);
    if (i >= 0) {
      list[i] = r;
    } else {
      list.insert(0, r);
    }
    _set(state.copyWith(recipes: list));
  }

  void deleteRecipe(String id) => _set(state.copyWith(
        recipes: state.recipes.where((r) => r.id != id).toList(),
        favorites: {...state.favorites}..remove(id),
        entries: state.entries.where((e) => e.recipeId != id).toList(),
      ));

  // --- Planning ----------------------------------------------------------

  /// Ajoute un repas dans un créneau ; remplace ce qui s'y trouvait.
  PlanEntry setMeal(DateTime date, SlotKind slot, {String? recipeId, String? freeText, int? guests}) {
    final g = state.currentGroup;
    final e = PlanEntry(
      id: newId(),
      groupId: g.id,
      date: dateOnly(date),
      slot: slot,
      recipeId: recipeId,
      freeText: freeText,
      guests: guests ?? g.size.clamp(1, 99),
    );
    _set(state.copyWith(entries: [
      ...state.entries.where((x) => !(x.groupId == g.id && x.date == e.date && x.slot == slot)),
      e,
    ]));
    return e;
  }

  void removeEntry(String id) => _set(state.copyWith(entries: state.entries.where((e) => e.id != id).toList()));

  void updateEntry(PlanEntry e) =>
      _set(state.copyWith(entries: [for (final x in state.entries) x.id == e.id ? e : x]));

  /// Déplace un repas vers un autre créneau (F-PLN-04) ; échange si le créneau est occupé.
  void moveEntry(String id, DateTime date, SlotKind slot) {
    final src = state.entries.firstWhere((e) => e.id == id);
    final d = dateOnly(date);
    final target = state.entries
        .where((e) => e.groupId == src.groupId && e.date == d && e.slot == slot && e.id != id)
        .firstOrNull;
    _set(state.copyWith(entries: [
      for (final e in state.entries)
        if (e.id == id)
          e.copyWith(date: d, slot: slot)
        else if (target != null && e.id == target.id)
          e.copyWith(date: src.date, slot: src.slot)
        else
          e,
    ]));
  }

  /// Pose un repas existant sur un autre créneau, en copie (duplication).
  void duplicateEntry(String id, DateTime date, SlotKind slot) {
    final src = state.entries.firstWhere((e) => e.id == id);
    setMeal(date, slot, recipeId: src.recipeId, freeText: src.freeText, guests: src.guests);
  }

  /// Retire [removeIds] et ajoute [add] en une fois (validation / annulation du bouton magique).
  void replaceEntries({required Set<String> removeIds, required List<PlanEntry> add}) =>
      _set(state.copyWith(entries: [...state.entries.where((e) => !removeIds.contains(e.id)), ...add]));

  PlanEntry newEntry(DateTime date, SlotKind slot, String recipeId, {int? guests}) {
    final g = state.currentGroup;
    return PlanEntry(
      id: newId(),
      groupId: g.id,
      date: dateOnly(date),
      slot: slot,
      recipeId: recipeId,
      guests: guests ?? g.size.clamp(1, 99),
    );
  }

  // --- Liste de courses --------------------------------------------------

  /// Génère la liste du groupe courant pour [from]..[to] (F-SHP-01, 07).
  void generateShopping(DateTime from, DateTime to) {
    final g = state.currentGroup;
    final f = dateOnly(from);
    final t = dateOnly(to);
    final inRange = state.entries
        .where((e) => e.groupId == g.id && !e.date.isBefore(f) && !e.date.isAfter(t))
        .toList();
    final items = gen.generateShopping(
      groupId: g.id,
      entries: inRange,
      recipes: {for (final r in state.recipes) r.id: r},
      pantry: state.pantry,
      existing: state.shopping,
      newId: newId,
    );
    _set(state.copyWith(
      shopping: [...state.shopping.where((i) => i.groupId != g.id), ...items],
      lists: {
        ...state.lists,
        g.id: ShoppingMeta(from: f, to: t, meals: inRange.where((e) => e.recipeId != null).length),
      },
    ));
  }

  void _mapItem(String id, ShoppingItem Function(ShoppingItem) f) =>
      _set(state.copyWith(shopping: [for (final i in state.shopping) i.id == id ? f(i) : i]));

  void toggleItem(String id) => _mapItem(id, (i) => i.copyWith(checked: !i.checked));

  void setItemQty(String id, double qty) => _mapItem(id, (i) => i.copyWith(qty: qty));

  void removeItem(String id) => _set(state.copyWith(shopping: state.shopping.where((i) => i.id != id).toList()));

  void addManualItem(String label, {double qty = 1, String unit = '', Aisle aisle = Aisle.home}) {
    final clean = label.trim();
    if (clean.isEmpty) return;
    _set(state.copyWith(shopping: [
      ...state.shopping,
      ShoppingItem(
        id: newId(),
        groupId: state.currentGroupId,
        label: clean,
        qty: qty,
        unit: unit,
        aisle: aisle,
        manual: true,
        sources: const [],
      ),
    ]));
  }

  void clearChecked() => _set(state.copyWith(
        shopping: state.shopping.where((i) => !(i.groupId == state.currentGroupId && i.checked)).toList(),
      ));
}

// ---------------------------------------------------------------------------
// Providers dérivés
// ---------------------------------------------------------------------------

final currentGroupProvider = Provider<Group>((ref) => ref.watch(appStoreProvider.select((d) => d.currentGroup)));

final recipesByIdProvider = Provider<Map<String, Recipe>>(
  (ref) => {for (final r in ref.watch(appStoreProvider.select((d) => d.recipes))) r.id: r},
);

final groupEntriesProvider = Provider<List<PlanEntry>>((ref) {
  final d = ref.watch(appStoreProvider);
  return d.entries.where((e) => e.groupId == d.currentGroupId).toList();
});

final groupShoppingProvider = Provider<List<ShoppingItem>>((ref) {
  final d = ref.watch(appStoreProvider);
  return d.shopping.where((i) => i.groupId == d.currentGroupId).toList();
});

/// Dernière date où chaque recette a été planifiée dans le passé ou aujourd'hui
/// (F-REC-08, « dernière fois cuisiné »).
final lastCookedProvider = Provider<Map<String, DateTime>>((ref) {
  final today = dateOnly(DateTime.now());
  final out = <String, DateTime>{};
  for (final e in ref.watch(groupEntriesProvider)) {
    final id = e.recipeId;
    if (id == null || e.date.isAfter(today)) continue;
    final cur = out[id];
    if (cur == null || e.date.isAfter(cur)) out[id] = e.date;
  }
  return out;
});

/// Lundi de la semaine affichée dans le planning.
class VisibleWeek extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day - (n.weekday - 1));
  }

  void shift(int weeks) => state = DateTime(state.year, state.month, state.day + 7 * weeks);

  void reset() {
    final n = DateTime.now();
    state = DateTime(n.year, n.month, n.day - (n.weekday - 1));
  }
}

final visibleWeekProvider = NotifierProvider<VisibleWeek, DateTime>(VisibleWeek.new);
