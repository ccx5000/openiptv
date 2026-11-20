import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database.dart';

/// Two-way sync between the local Drift DB and Supabase, scoped to one
/// profile. Local writes always succeed first (offline-first); remote
/// pushes happen debounced, pulls use an `updated_at` watermark.
class SyncService {
  final AppDatabase db;
  final SupabaseClient client;

  Timer? _debounce;
  bool syncing = false;
  DateTime? lastSyncAt;
  String? lastError;

  SyncService(this.db, this.client);

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
    final c = client;

    final favs = await (db.select(db.favoriteRows)
          ..where((r) => r.profileId.equals(profileId)))
        .get();
    for (final f in favs) {
      await c.from('favorites').upsert({
        'profile_id': f.profileId,
        'playlist_id': f.playlistId,
        'item_kind': f.kind,
        'item_id': f.itemId,
        'title': f.title,
        'logo_url': f.logoUrl,
        'state': f.state,
        'updated_at': f.updatedAt.toIso8601String(),
      }, onConflict: 'profile_id,item_kind,item_id,state');
    }

    final prog = await (db.select(db.progressRows)
          ..where((r) => r.profileId.equals(profileId)))
        .get();
    for (final p in prog) {
      await c.from('watch_progress').upsert({
        'profile_id': p.profileId,
        'playlist_id': p.playlistId,
        'item_kind': p.kind,
        'item_id': p.itemId,
        'title': p.title,
        'position_ms': p.positionMs,
        'duration_ms': p.durationMs,
        'updated_at': p.updatedAt.toIso8601String(),
      }, onConflict: 'profile_id,item_kind,item_id');
    }

    final views = await (db.select(db.viewedRows)
          ..where((r) => r.profileId.equals(profileId)))
        .get();
    for (final v in views) {
      await c.from('views').upsert({
        'profile_id': v.profileId,
        'item_kind': v.kind,
        'item_id': v.itemId,
        'updated_at': v.updatedAt.toIso8601String(),
      }, onConflict: 'profile_id,item_kind,item_id');
    }

    final pls = await db.select(db.playlistRows).get();
    for (final pl in pls) {
      await c.from('playlists').upsert({
        'profile_id': profileId,
        'name': pl.name,
        'kind': pl.kind,
        'host': pl.host,
        'm3u_url': pl.m3uUrl,
        'epg_url': pl.epgUrl,
        'updated_at': pl.updatedAt.toIso8601String(),
      });
    }
  }

  // ---- PULL --------------------------------------------------------------

  Future<void> pull(String profileId) async {
    final c = client;

    for (final table in const ['favorites', 'watch_progress', 'views']) {
      final cursor = await db.meta('sync.$table');
      final rows = await c
          .from(table)
          .select()
          .eq('profile_id', profileId)
          .gt('updated_at', cursor ?? '1970-01-01T00:00:00Z');
      String newest = cursor ?? '1970-01-01T00:00:00Z';
      for (final r in rows) {
        final row = r as Map<String, dynamic>;
        final updated = row['updated_at']?.toString() ?? '';
        if (updated.compareTo(newest) > 0) newest = updated;
        await _applyRemote(table, profileId, row);
      }
      if (rows.isNotEmpty) await db.setMeta('sync.$table', newest);
    }
  }

  Future<void> _applyRemote(
      String table, String profileId, Map<String, dynamic> row) async {
    final updated =
        DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.now();
    final kind = row['item_kind'].toString();
    final itemId = row['item_id'].toString();

    switch (table) {
      case 'favorites':
        await db.into(db.favoriteRows).insertOnConflictUpdate(
              FavoriteRowsCompanion.insert(
                key: _favKey(row),
                profileId: profileId,
                playlistId: row['playlist_id']?.toString(),
                kind: kind,
                itemId: itemId,
                title: row['title'].toString(),
                logoUrl: row['logo_url']?.toString(),
                state: row['state'].toString(),
                updatedAt: Value(updated),
              ),
            );
        break;
      case 'watch_progress':
        await db.into(db.progressRows).insertOnConflictUpdate(
              ProgressRowsCompanion.insert(
                key: _progKey(row),
                profileId: profileId,
                playlistId: row['playlist_id']?.toString(),
                kind: kind,
                itemId: itemId,
                title: row['title'].toString(),
                positionMs: (row['position_ms'] as int?) ?? 0,
                durationMs: (row['duration_ms'] as int?) ?? 0,
                updatedAt: Value(updated),
              ),
            );
        break;
      case 'views':
        await db.into(db.viewedRows).insertOnConflictUpdate(
              ViewedRowsCompanion.insert(
                key: '$profileId:$kind:$itemId',
                profileId: profileId,
                kind: kind,
                itemId: itemId,
                updatedAt: Value(updated),
              ),
            );
        break;
    }
  }

  String _favKey(Map<String, dynamic> row) =>
      '${row['profile_id']}:${row['item_kind']}:${row['item_id']}:${row['state']}';

  String _progKey(Map<String, dynamic> row) =>
      '${row['profile_id']}:${row['item_kind']}:${row['item_id']}';

  Future<void> dispose() async {
    _debounce?.cancel();
  }
}
