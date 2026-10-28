import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_store.dart';
import 'auth_service.dart';
import 'models.dart';

/// État de la synchronisation, affiché dans le profil.
enum SyncStatus { idle, syncing, error }

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  void set(SyncStatus s) => state = s;
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(SyncStatusNotifier.new);

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});

const _pendingInviteKey = 'popote.pendingInvite';

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

/// Trie les clés : `jsonb` de Postgres ne conserve pas l'ordre, on compare donc des formes canoniques.
Object? _canon(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _canon(v[k])};
  }
  if (v is List) return v.map(_canon).toList();
  return v;
}

String _canonJson(Object? v) => jsonEncode(_canon(v));

/// Un élément partagé d'un groupe (recette, repas planifié, article de courses, liste).
class _Doc {
  _Doc(this.gid, this.kind, this.id, this.data);

  final String gid;
  final String kind;
  final String id;
  final Map<String, dynamic> data;

  String get key => '$gid|$kind|$id';
  String get canon => _canonJson(data);
}

/// Le chemin de la photo est propre à l'appareil : il n'est jamais synchronisé.
Map<String, dynamic> _recipeData(Recipe r) => {...r.toJson(), 'photo': null};

List<_Doc> _localDocs(AppData d, Set<String> gids) => [
      for (final r in d.recipes)
        if (r.groupId != null && gids.contains(r.groupId)) _Doc(r.groupId!, 'recipe', r.id, _recipeData(r)),
      for (final e in d.entries)
        if (gids.contains(e.groupId)) _Doc(e.groupId, 'entry', e.id, e.toJson()),
      for (final i in d.shopping)
        if (gids.contains(i.groupId)) _Doc(i.groupId, 'item', i.id, i.toJson()),
      for (final l in d.lists.entries)
        if (gids.contains(l.key)) _Doc(l.key, 'list', l.key, l.value.toJson()),
    ];

/// Applique des lignes `docs` reçues du serveur à [d] et met à jour [snap] (dernier état connu du serveur).
AppData _applyRows(AppData d, List<Map<String, dynamic>> rows, Map<String, String> snap) {
  final recipes = {for (final r in d.recipes) r.id: r};
  final entries = {for (final e in d.entries) e.id: e};
  final items = {for (final i in d.shopping) i.id: i};
  final lists = {...d.lists};
  var changed = false;

  for (final row in rows) {
    final gid = row['group_id'] as String;
    final kind = row['kind'] as String;
    final id = row['id'] as String;
    final key = '$gid|$kind|$id';

    if (row['deleted'] == true) {
      switch (kind) {
        case 'recipe':
          changed |= recipes.remove(id) != null;
        case 'entry':
          changed |= entries.remove(id) != null;
        case 'item':
          changed |= items.remove(id) != null;
        case 'list':
          changed |= lists.remove(id) != null;
      }
      snap.remove(key);
      continue;
    }

    try {
      final data = Map<String, dynamic>.from(row['data'] as Map);
      switch (kind) {
        case 'recipe':
          final r = Recipe.fromJson({...data, 'photo': recipes[id]?.photoPath, 'gid': gid});
          final canon = _canonJson(_recipeData(r));
          if (snap[key] != canon) {
            recipes[id] = r;
            changed = true;
          }
          snap[key] = canon;
        case 'entry':
          final e = PlanEntry.fromJson(data);
          final canon = _canonJson(e.toJson());
          if (snap[key] != canon) {
            entries[id] = e;
            changed = true;
          }
          snap[key] = canon;
        case 'item':
          final i = ShoppingItem.fromJson(data);
          final canon = _canonJson(i.toJson());
          if (snap[key] != canon) {
            items[id] = i;
            changed = true;
          }
          snap[key] = canon;
        case 'list':
          final m = ShoppingMeta.fromJson(data);
          final canon = _canonJson(m.toJson());
          if (snap[key] != canon) {
            lists[id] = m;
            changed = true;
          }
          snap[key] = canon;
      }
    } catch (_) {
      // Document d'un format inconnu (version plus récente de l'appli) : on l'ignore.
    }
  }

  // Sans changement on rend le même objet : sinon chaque passage de synchro déclencherait le suivant.
  if (!changed) return d;
  return d.copyWith(
    recipes: recipes.values.toList(),
    entries: entries.values.toList(),
    shopping: items.values.toList(),
    lists: lists,
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Synchronisation locale ↔ Supabase (spec §5.3 : local-first, le serveur est la copie partagée).
///
/// - Les modifications locales partent après un court délai ; les distantes arrivent par
///   Realtime. En cas de conflit sur un même élément, le dernier écrit (heure serveur) gagne.
/// - Au premier passage sur un appareil, si le compte a déjà des groupes, ils remplacent les
///   données locales de démarrage ; sinon les données locales sont envoyées.
/// - Favoris, garde-manger, thème et photos restent propres à l'appareil.
class SyncService {
  SyncService(this._ref) {
    _ref.listen<AppData>(appStoreProvider, (prev, next) {
      if (!AuthService.configured) return;
      if (next.user == null) {
        _onSignedOut();
      } else if (prev?.user == null) {
        schedule(immediately: true);
      } else if (!identical(prev, next)) {
        schedule();
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  Timer? _debounce;
  RealtimeChannel? _channel;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  String? _uid;
  bool _initialized = false;
  String? _cursor;
  var _snap = <String, String>{};
  var _groupSnap = <String, String>{};
  var _knownGroups = <String>{};

  SupabaseClient get _client => Supabase.instance.client;

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _channel?.unsubscribe();
  }

  void schedule({bool immediately = false}) {
    if (_disposed || !AuthService.configured) return;
    _debounce?.cancel();
    _debounce = Timer(immediately ? Duration.zero : const Duration(milliseconds: 1500), _run);
  }

  /// Envoie tout de suite les modifications en attente (avant une déconnexion).
  Future<void> flush() async {
    if (!AuthService.configured) return;
    _debounce?.cancel();
    await _run();
  }

  Future<void>? _current;

  /// Un seul passage à la fois ; une demande pendant un passage en provoque un second juste après.
  Future<void> _run() {
    if (_running) {
      _again = true;
      return _current!;
    }
    _running = true;
    return _current = _runLoop();
  }

  Future<void> _runLoop() async {
    final status = _ref.read(syncStatusProvider.notifier);
    try {
      do {
        _again = false;
        if (_client.auth.currentUser == null) break;
        status.set(SyncStatus.syncing);
        await _sync();
        status.set(SyncStatus.idle);
      } while (_again && !_disposed);
    } catch (_) {
      // Hors ligne ou erreur serveur : les données locales restent la référence, on réessaiera.
      status.set(SyncStatus.error);
    } finally {
      _running = false;
    }
  }

  // --- Persistance de l'état de synchro ------------------------------------

  String _stateKey(String uid) => 'popote.sync.$uid';

  void _loadState(String uid) {
    _uid = uid;
    _initialized = false;
    _cursor = null;
    _snap = {};
    _groupSnap = {};
    _knownGroups = {};
    final raw = _ref.read(prefsProvider).getString(_stateKey(uid));
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _initialized = j['init'] as bool? ?? false;
      _cursor = j['cursor'] as String?;
      _snap = (j['snap'] as Map).map((k, v) => MapEntry(k as String, v as String));
      _groupSnap = (j['gsnap'] as Map).map((k, v) => MapEntry(k as String, v as String));
      _knownGroups = (j['groups'] as List).cast<String>().toSet();
    } catch (_) {
      _initialized = false;
    }
  }

  void _saveState() {
    final uid = _uid;
    if (uid == null) return;
    _ref.read(prefsProvider).setString(
          _stateKey(uid),
          jsonEncode({
            'init': _initialized,
            'cursor': _cursor,
            'snap': _snap,
            'gsnap': _groupSnap,
            'groups': _knownGroups.toList(),
          }),
        );
  }

  void _onSignedOut() {
    _debounce?.cancel();
    _channel?.unsubscribe();
    _channel = null;
    final uid = _uid;
    if (uid != null) _ref.read(prefsProvider).remove(_stateKey(uid));
    _uid = null;
    _initialized = false;
  }

  // --- Invitations ---------------------------------------------------------

  /// Mémorise un code reçu avant la connexion ; il sera utilisé à la première synchro.
  void setPendingInvite(String code) => _ref.read(prefsProvider).setString(_pendingInviteKey, code.trim().toUpperCase());

  /// Rejoint un groupe avec un code. Hors connexion, le code est gardé pour plus tard.
  /// Renvoie `false` si le code est invalide ou expiré.
  Future<bool> joinWithCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return false;
    if (!AuthService.configured || _client.auth.currentUser == null) {
      setPendingInvite(clean);
      return true;
    }
    try {
      final gid = await _client.rpc('join_group', params: {'p_code': clean}) as String;
      await flush();
      _ref.read(appStoreProvider.notifier).selectGroup(gid);
      return true;
    } on PostgrestException {
      return false;
    }
  }

  /// Crée un code d'invitation valable 7 jours pour [groupId].
  Future<String?> createInvite(String groupId) async {
    if (!AuthService.configured || _client.auth.currentUser == null) return null;
    // Le groupe doit exister sur le serveur avant d'y inviter quelqu'un.
    await flush();
    try {
      return await _client.rpc('create_invite', params: {'p_group_id': groupId}) as String;
    } on PostgrestException {
      return null;
    }
  }

  /// Quitte un groupe (le groupe disparaît s'il n'a plus de membre).
  Future<bool> leaveGroup(String id) => _removeGroup(id, () async {
        await _client.rpc('leave_group', params: {'p_group_id': id});
        return true;
      });

  /// Supprime un groupe pour tous ses membres (réservé aux admins : sinon la ligne n'est pas supprimée).
  Future<bool> deleteGroup(String id) => _removeGroup(id, () async {
        final deleted = await _client.from('groups').delete().eq('id', id).select();
        return deleted.isNotEmpty;
      });

  Future<bool> _removeGroup(String id, Future<bool> Function() remote) async {
    if (AuthService.configured && _client.auth.currentUser != null && _knownGroups.contains(id)) {
      try {
        if (!await remote()) return false;
      } catch (_) {
        return false;
      }
    }
    _ref.read(appStoreProvider.notifier).removeGroup(id);
    _snap.removeWhere((k, _) => k.startsWith('$id|'));
    _knownGroups.remove(id);
    _groupSnap.remove(id);
    _saveState();
    schedule();
    return true;
  }

  Future<void> _joinPending() async {
    final prefs = _ref.read(prefsProvider);
    final code = prefs.getString(_pendingInviteKey);
    if (code == null) return;
    try {
      await _client.rpc('join_group', params: {'p_code': code});
      await prefs.remove(_pendingInviteKey);
    } on PostgrestException {
      // Code invalide ou expiré : inutile de le garder.
      await prefs.remove(_pendingInviteKey);
    }
  }

  // --- Synchronisation -------------------------------------------------------

  static const _groupColumns = 'id,name,color,personal,settings,group_members(user_id,role,profiles(name,email))';

  Future<List<Map<String, dynamic>>> _fetchGroups() async {
    final rows = await _client.from('groups').select(_groupColumns);
    return List<Map<String, dynamic>>.from(rows);
  }

  Group _toGroup(Map<String, dynamic> row, String uid) {
    final members = <Member>[
      for (final m in (row['group_members'] as List? ?? const []))
        Member(
          ((m as Map)['profiles'] as Map?)?['name'] as String? ?? '?',
          enumByName(Role.values, m['role']) ?? Role.member,
          isMe: m['user_id'] == uid,
          userId: m['user_id'] as String?,
          email: ((m)['profiles'] as Map?)?['email'] as String?,
        ),
    ];
    return Group.fromRemote(
      id: row['id'] as String,
      name: row['name'] as String,
      color: (row['color'] as num).toInt(),
      personal: row['personal'] as bool? ?? false,
      settings: Map<String, dynamic>.from(row['settings'] as Map? ?? const {}),
      members: members,
    );
  }

  String _groupCanon(Group g) => _canonJson({'name': g.name, 'color': g.color, 'settings': g.settingsJson()});

  Future<void> _sync() async {
    final uid = _client.auth.currentUser!.id;
    if (_uid != uid) _loadState(uid);
    final store = _ref.read(appStoreProvider.notifier);

    await _joinPending();

    // 1. Groupes : le serveur est la référence des noms, membres et réglages.
    var remote = await _fetchGroups();
    final adopt = !_initialized && remote.isNotEmpty;

    if (adopt) {
      // Appareil neuf pour ce compte : on part des données du serveur.
      final groups = [for (final r in remote) _toGroup(r, uid)];
      store.apply((d) => d.copyWith(
            groups: groups,
            currentGroupId: groups.first.id,
            recipes: const [],
            entries: const [],
            shopping: const [],
            lists: const {},
            favorites: <String>{},
          ));
      _snap = {};
      _cursor = null;
      _knownGroups = {};
      _groupSnap = {for (final g in groups) g.id: _groupCanon(g)};
    } else {
      var changed = false;
      final onServer = {for (final r in remote) r['id'] as String};
      for (final g in _ref.read(appStoreProvider).groups) {
        if (!onServer.contains(g.id) && !_knownGroups.contains(g.id)) {
          await _client.rpc('create_group', params: {
            'p_id': g.id,
            'p_name': g.name,
            'p_color': g.color,
            'p_personal': g.personal,
            'p_settings': g.settingsJson(),
          });
          _groupSnap[g.id] = _groupCanon(g);
          changed = true;
        } else if (onServer.contains(g.id)) {
          final canon = _groupCanon(g);
          final known = _groupSnap[g.id];
          final isAdmin = g.members.any((m) => m.isMe && m.role == Role.admin);
          if (known != null && known != canon && isAdmin) {
            await _client.from('groups').update({'name': g.name, 'color': g.color, 'settings': g.settingsJson()}).eq('id', g.id);
            _groupSnap[g.id] = canon;
            changed = true;
          }
        }
      }
      if (changed) remote = await _fetchGroups();
    }

    final remoteGroups = [for (final r in remote) _toGroup(r, uid)];
    final remoteIds = {for (final g in remoteGroups) g.id};
    final newIds = remoteIds.difference(_knownGroups);
    final leftIds = _knownGroups.difference(remoteIds);

    if (!adopt) {
      store.apply((d) {
        final order = {for (final (i, g) in d.groups.indexed) g.id: i};
        final before = jsonEncode([for (final g in d.groups) g.toJson()]);
        final merged = [
          ...remoteGroups,
          // Groupes créés ici dont l'envoi a échoué : on les garde pour le prochain essai.
          for (final g in d.groups)
            if (!remoteIds.contains(g.id) && !_knownGroups.contains(g.id)) g,
        ]..sort((a, b) => (order[a.id] ?? 1 << 20).compareTo(order[b.id] ?? 1 << 20));
        final current = merged.any((g) => g.id == d.currentGroupId) ? d.currentGroupId : merged.first.id;
        final unchanged = leftIds.isEmpty &&
            current == d.currentGroupId &&
            before == jsonEncode([for (final g in merged) g.toJson()]);
        if (unchanged) return d;
        return d.copyWith(
          groups: merged,
          currentGroupId: current,
          recipes: d.recipes.where((r) => !leftIds.contains(r.groupId)).toList(),
          entries: d.entries.where((e) => !leftIds.contains(e.groupId)).toList(),
          shopping: d.shopping.where((i) => !leftIds.contains(i.groupId)).toList(),
          lists: {...d.lists}..removeWhere((k, _) => leftIds.contains(k)),
        );
      });
    }
    for (final g in remoteGroups) {
      _groupSnap[g.id] = _groupCanon(g);
    }
    _groupSnap.removeWhere((k, _) => !remoteIds.contains(k));
    for (final id in leftIds) {
      _snap.removeWhere((k, _) => k.startsWith('$id|'));
    }

    // 2. Documents des groupes nouvellement visibles (adhésion, ou première synchro).
    if (newIds.isNotEmpty) {
      final rows = await _pullGroups(newIds.toList());
      store.apply((d) => _applyRows(d, rows, _snap));
    }

    // 3. Envoi des modifications locales.
    await _push(remoteIds);

    // 4. Réception des modifications distantes depuis le dernier passage.
    await _pullSince(remoteIds);

    _knownGroups = remoteIds;
    _initialized = true;
    _saveState();
    _listenRealtime();
  }

  Future<void> _push(Set<String> gids) async {
    final docs = _localDocs(_ref.read(appStoreProvider), gids);
    final seen = {for (final d in docs) d.key};

    final rows = <Map<String, dynamic>>[];
    final pushed = <String, String?>{};
    for (final d in docs) {
      if (_snap[d.key] == d.canon) continue;
      rows.add({'group_id': d.gid, 'kind': d.kind, 'id': d.id, 'data': d.data, 'deleted': false});
      pushed[d.key] = d.canon;
    }
    // Supprimé localement depuis le dernier envoi : on pose une « pierre tombale ».
    for (final key in _snap.keys) {
      if (seen.contains(key)) continue;
      final parts = key.split('|');
      if (parts.length != 3 || !gids.contains(parts[0])) continue;
      rows.add({'group_id': parts[0], 'kind': parts[1], 'id': parts[2], 'data': <String, dynamic>{}, 'deleted': true});
      pushed[key] = null;
    }

    for (var i = 0; i < rows.length; i += 200) {
      final chunk = rows.sublist(i, i + 200 > rows.length ? rows.length : i + 200);
      await _client.from('docs').upsert(chunk, onConflict: 'group_id,kind,id');
      for (final r in chunk) {
        final key = '${r['group_id']}|${r['kind']}|${r['id']}';
        final canon = pushed[key];
        if (canon == null) {
          _snap.remove(key);
        } else {
          _snap[key] = canon;
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> _pullGroups(List<String> gids) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0;; from += 1000) {
      final page = List<Map<String, dynamic>>.from(
        await _client.from('docs').select().inFilter('group_id', gids).order('updated_at').range(from, from + 999),
      );
      out.addAll(page);
      if (page.length < 1000) break;
    }
    // Le curseur doit couvrir ces lignes pour ne pas les relire à chaque fois.
    for (final r in out) {
      final t = r['updated_at'] as String?;
      if (t != null && (_cursor == null || t.compareTo(_cursor!) > 0)) _cursor = t;
    }
    return out;
  }

  Future<void> _pullSince(Set<String> gids) async {
    final store = _ref.read(appStoreProvider.notifier);
    while (true) {
      var query = _client.from('docs').select();
      if (_cursor != null) query = query.gt('updated_at', _cursor!);
      final page = List<Map<String, dynamic>>.from(await query.order('updated_at').limit(1000));
      if (page.isEmpty) break;
      final mine = page.where((r) => gids.contains(r['group_id'])).toList();
      if (mine.isNotEmpty) store.apply((d) => _applyRows(d, mine, _snap));
      _cursor = page.last['updated_at'] as String;
      if (page.length < 1000) break;
    }
  }

  void _listenRealtime() {
    if (_channel != null) return;
    _channel = _client
        .channel('popote-sync')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'docs',
          callback: (_) => schedule(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          callback: (_) => schedule(),
        )
        .subscribe();
  }
}
