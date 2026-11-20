import 'dart:async';

import 'package:drift/drift.dart' show Value;

import '../backend/backend.dart';
import '../database/database.dart';

/// Two-way sync between the local Drift DB and the selected backend,
/// scoped to one profile. Local writes always succeed first (offline-first);
/// pushes are debounced, pulls use an `updated_at` watermark per table.
class SyncService {
  final AppDatabase db;
  final Backend backend;

  Timer? _debounce;
  bool syncing = false;
  DateTime? lastSyncAt;
  String? lastError;

  final Map<String, String> _cursors = {};

  SyncService(this.db, this.backend);

  void schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), () => fullSync());
  }

  Future<void> fullSync() async {
    final profileId = await db.meta('active_profile_id');
    if (profileId == null) return;
    syncing = true;
    lastError = null;
    try {
      await push(profileId);
      await pull(profileId);
      lastSyncAt = DateTime.now();
    } catch (e) {
      lastError = e.toString();
    } finally {
      syncing = false;
    }
  }

  // ---- PUSH --------------------------------------------------------------

  Future<void> push(String profileId) async {
    final playlists = (await db.select(db.playlistRows).get())
        .map((r) => <String, dynamic>{
              'name': r.name,
              'kind': r.kind,
              'host': r.host,
              'm3u_url': r.m3uUrl,
              'epg_url': r.epgUrl,
              'updated_at': r.updatedAt.toIso8601String(),
            })
        .toList();

    final favs = await (db.select(db.favoriteRows)
          ..where((r) => r.profileId.equals(profileId)))
        .get();
    final favorites = favs
        .map((f) => <String, dynamic>{
              'playlist_id': f.playlistId,
              'item_kind': f.kind,
              'item_id': f.itemId,
              'title': f.title,
              'logo_url': f.logoUrl,
              'state': f.state,
              'updated_at': f.updatedAt.toIso8601String(),
            })
        .toList();

    final progs = await (db.select(db.progressRows)
          ..where((r) => r.profileId.equals(profileId)))
        .get();
    final progress = progs
        .map((p) => <String, dynamic>{
              'playlist_id': p.playlistId,
              'item_kind': p.kind,
              'item_id': p.itemId,
              'title': p.title,
              'position_ms': p.positionMs,
              'duration_ms': p.durationMs,
              'updated_at': p.updatedAt.toIso8601String(),
            })
        .toList();

    final vws = await (db.select(db.viewedRows)
          ..where((r) => r.profileId.equals(profileId)))
        .get();
    final views = vws
        .map((v) => <String, dynamic>{
              'item_kind': v.kind,
              'item_id': v.itemId,
              'updated_at': v.updatedAt.toIso8601String(),
            })
        .toList();

    await backend.push(
      profileId,
      PushPayload(
        playlists: playlists,
        favorites: favorites,
        watchProgress: progress,
        views: views,
      ),
    );
  }

  // ---- PULL --------------------------------------------------------------

  Future<String> _cursor(String table) async {
    if (!_cursors.containsKey(table)) {
      _cursors[table] = await db.meta('sync.$table') ?? '1970-01-01T00:00:00Z';
    }
    return _cursors[table]!;
  }

  Future<void> _advanceCursor(
      String table, List<Map<String, dynamic>> rows) async {
    final current = await _cursor(table);
    var newest = current;
    for (final r in rows) {
      final u = r['updated_at']?.toString() ?? '';
      if (u.compareTo(newest) > 0) newest = u;
    }
    if (newest != current) {
      _cursors[table] = newest;
      await db.setMeta('sync.$table', newest);
    }
  }

  Future<void> pull(String profileId) async {
    final result = await backend.pull(profileId, {
      'favorites': await _cursor('favorites'),
      'watch_progress': await _cursor('watch_progress'),
      'views': await _cursor('views'),
    });

    for (final r in result.favorites) {
      final updated =
          DateTime.tryParse(r['updated_at']?.toString() ?? '') ?? DateTime.now();
      final kind = r['item_kind'].toString();
      final itemId = r['item_id'].toString();
      await db.into(db.favoriteRows).insertOnConflictUpdate(
            FavoriteRowsCompanion.insert(
              key: '$profileId:$kind:$itemId:${r['state']}',
              profileId: profileId,
              playlistId: r['playlist_id']?.toString(),
              kind: kind,
              itemId: itemId,
              title: r['title'].toString(),
              logoUrl: r['logo_url']?.toString(),
              state: r['state'].toString(),
              updatedAt: Value(updated),
            ),
          );
    }
    await _advanceCursor('favorites', result.favorites);

    for (final r in result.watchProgress) {
      final updated =
          DateTime.tryParse(r['updated_at']?.toString() ?? '') ?? DateTime.now();
      final kind = r['item_kind'].toString();
      final itemId = r['item_id'].toString();
      await db.into(db.progressRows).insertOnConflictUpdate(
            ProgressRowsCompanion.insert(
              key: '$profileId:$kind:$itemId',
              profileId: profileId,
              playlistId: r['playlist_id']?.toString(),
              kind: kind,
              itemId: itemId,
              title: r['title'].toString(),
              positionMs: ((r['position_ms'] as num?) ?? 0).toInt(),
              durationMs: ((r['duration_ms'] as num?) ?? 0).toInt(),
              updatedAt: Value(updated),
            ),
          );
    }
    await _advanceCursor('watch_progress', result.watchProgress);

    for (final r in result.views) {
      final updated =
          DateTime.tryParse(r['updated_at']?.toString() ?? '') ?? DateTime.now();
      final kind = r['item_kind'].toString();
      final itemId = r['item_id'].toString();
      await db.into(db.viewedRows).insertOnConflictUpdate(
            ViewedRowsCompanion.insert(
              key: '$profileId:$kind:$itemId',
              profileId: profileId,
              kind: kind,
              itemId: itemId,
              updatedAt: Value(updated),
            ),
          );
    }
    await _advanceCursor('views', result.views);
  }

  Future<void> dispose() async {
    _debounce?.cancel();
  }
}
