import 'dart:convert';

import '../models/models.dart';
import '../database/database.dart';
import 'backend.dart';

/// Pure offline backend: no account, no network. Profiles live in the local
/// meta table; favorites/progress are already stored locally by the app, so
/// push/pull are no-ops.
class LocalBackend implements Backend {
  final AppDatabase db;
  LocalBackend(this.db);

  static const _profilesKey = 'local.profiles';

  @override
  Future<void> init() async {
    final raw = await db.meta(_profilesKey);
    if (raw == null) {
      final def = [
        {
          'id': 'lp_' + DateTime.now().millisecondsSinceEpoch.toString(),
          'name': 'Ich',
          'avatar_color': '#4F8CFF',
          'is_kids': false,
        }
      ];
      await db.setMeta(_profilesKey, jsonEncode(def));
    }
  }

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await db.meta(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
        .toList();
  }

  Future<void> _write(List<Map<String, dynamic>> list) =>
      db.setMeta(_profilesKey, jsonEncode(list));

  @override
  bool get signedIn => true;

  @override
  String get userId => 'local';

  @override
  String? get userEmail => 'Lokal (kein Sync)';

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<List<UserProfile>> fetchProfiles() async {
    final list = await _read();
    return list
        .map<UserProfile>((r) => UserProfile(
              id: r['id'].toString(),
              name: r['name'].toString(),
              avatarColor: r['avatar_color']?.toString() ?? '#4F8CFF',
              isKids: (r['is_kids'] as bool?) ?? false,
            ))
        .toList();
  }

  @override
  Future<void> addProfile(String name, {bool kids = false}) async {
    final list = await _read();
    list.add({
      'id': 'lp_' + DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'avatar_color': '#4F8CFF',
      'is_kids': kids,
    });
    await _write(list);
  }

  @override
  Future<void> deleteProfile(String profileId) async {
    final list = await _read();
    await _write(
        list.where((r) => r['id'] != profileId).toList());
    await (db.delete(db.favoriteRows)
          ..where((r) => r.profileId.equals(profileId)))
        .go();
    await (db.delete(db.progressRows)
          ..where((r) => r.profileId.equals(profileId)))
        .go();
    await (db.delete(db.viewedRows)
          ..where((r) => r.profileId.equals(profileId)))
        .go();
  }

  @override
  Future<PullResult> pull(String profileId, Map<String, String> cursors) async {
    return const PullResult();
  }

  @override
  Future<void> push(String profileId, PushPayload payload) async {}

  /// True if this profile has any syncable data (favorites/progress/views).
  Future<bool> hasData(String profileId) async {
    final f = await (db.select(db.favoriteRows)
          ..where((r) => r.profileId.equals(profileId)))
        .getSingleOrNull();
    if (f != null) return true;
    final p = await (db.select(db.progressRows)
          ..where((r) => r.profileId.equals(profileId)))
        .getSingleOrNull();
    if (p != null) return true;
    final v = await (db.select(db.viewedRows)
          ..where((r) => r.profileId.equals(profileId)))
        .getSingleOrNull();
    return v != null;
  }

  /// Moves all local rows of [oldId] to [newId] (used when migrating from
  /// offline mode to a sync account).
  Future<void> migrateProfile(String oldId, String newId) async {
    final favs = await (db.select(db.favoriteRows)
          ..where((r) => r.profileId.equals(oldId)))
        .get();
    for (final row in favs) {
      await db.delete(db.favoriteRows).delete(row);
      await db
          .into(db.favoriteRows)
          .insertOnConflictUpdate(row.copyWith(
            profileId: newId,
            key: row.key.replaceFirst('$oldId:', '$newId:'),
          ));
    }
    final progs = await (db.select(db.progressRows)
          ..where((r) => r.profileId.equals(oldId)))
        .get();
    for (final row in progs) {
      await db.delete(db.progressRows).delete(row);
      await db
          .into(db.progressRows)
          .insertOnConflictUpdate(row.copyWith(
            profileId: newId,
            key: row.key.replaceFirst('$oldId:', '$newId:'),
          ));
    }
    final vws = await (db.select(db.viewedRows)
          ..where((r) => r.profileId.equals(oldId)))
        .get();
    for (final row in vws) {
      await db.delete(db.viewedRows).delete(row);
      await db
          .into(db.viewedRows)
          .insertOnConflictUpdate(row.copyWith(
            profileId: newId,
            key: row.key.replaceFirst('$oldId:', '$newId:'),
          ));
    }
    final active = await db.meta('active_profile_id');
    if (active == oldId) {
      await db.setMeta('active_profile_id', newId);
    }
  }
}

/// Delegating Backend whose implementation can be swapped at runtime
/// (offline mode by default, sync account enabled later in settings).
class BackendRouter implements Backend {
  Backend _impl;
  BackendRouter(this._impl);

  Backend get impl => _impl;

  Future<void> use(Backend next) async {
    await next.init();
    _impl = next;
  }

  @override
  Future<void> init() => _impl.init();

  @override
  bool get signedIn => _impl.signedIn;

  @override
  String? get userId => _impl.userId;

  @override
  String? get userEmail => _impl.userEmail;

  @override
  Future<void> signIn(String email, String password) => _impl.signIn(email, password);

  @override
  Future<void> signUp(String email, String password) => _impl.signUp(email, password);

  @override
  Future<void> signOut() => _impl.signOut();

  @override
  Future<List<UserProfile>> fetchProfiles() => _impl.fetchProfiles();

  @override
  Future<void> addProfile(String name, {bool kids = false}) =>
      _impl.addProfile(name, kids: kids);

  @override
  Future<void> deleteProfile(String profileId) => _impl.deleteProfile(profileId);

  @override
  Future<PullResult> pull(String profileId, Map<String, String> cursors) =>
      _impl.pull(profileId, cursors);

  @override
  Future<void> push(String profileId, PushPayload payload) =>
      _impl.push(profileId, payload);
}
