import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'database/database.dart';
import 'models/models.dart';
import 'services/m3u_parser.dart';
import 'services/settings_service.dart';
import 'services/sync_service.dart';
import 'services/xtream_client.dart';
import 'services/xmltv_parser.dart';

/// Central repository + observable state. Backed by local SQLite (Drift),
/// replicated to Supabase by [SyncService].
class LibraryController extends ChangeNotifier {
  final AppDatabase db;
  final SettingsService settings;
  final SyncService sync;

  final XtreamClient xtream = XtreamClient();
  final http.Client _http = http.Client();

  List<Playlist> playlists = [];
  final Map<String, ChannelRow> _channels = {};
  final Map<String, List<EpgEntry>> _epgCache = {};
  Map<String, FavoriteRow> favorites = {};
  Map<String, ProgressRow> progress = {};
  Set<String> viewed = {};
  Set<String> lockedCategories = {};

  String? activeProfileId;
  bool loadingLibrary = false;
  String? refreshError;

  LibraryController(this.db, this.settings, this.sync);

  Future<void> loadAll() async {
    loadingLibrary = true;
    notifyListeners();
    try {
      activeProfileId = await db.meta('active_profile_id');
      playlists = (await db.select(db.playlistRows).get())
          .map((r) => Playlist(
                id: r.id,
                name: r.name,
                type: r.kind == 'xtream' ? PlaylistType.xtream : PlaylistType.m3u,
                host: r.host,
                m3uUrl: r.m3uUrl,
                epgUrl: r.epgUrl,
              ))
          .toList();

      final allChannels = await db.select(db.channelRows).get();
      _channels..clear()..addEntries(allChannels.map((c) => MapEntry(c.key, c)));

      final lockedJson = await settings.get('locked_categories');
      lockedCategories = lockedJson == null
          ? {}
          : Set<String>.from(jsonDecode(lockedJson) as List);

      await loadProfileData();
    } finally {
      loadingLibrary = false;
      notifyListeners();
    }
  }

  Future<void> setActiveProfile(String profileId) async {
    activeProfileId = profileId;
    await db.setMeta('active_profile_id', profileId);
    await loadProfileData();
    unawaited(sync.fullSync().then((_) => notifyListeners()));
  }

  Future<void> loadProfileData() async {
    final pid = activeProfileId;
    if (pid == null) return;

    final favs = await (db.select(db.favoriteRows)
          ..where((r) => r.profileId.equals(pid)))
        .get();
    favorites = {for (final f in favs) f.key: f};

    final prog = await (db.select(db.progressRows)
          ..where((r) =>
              r.profileId.equals(pid) & r.positionMs.isBiggerThanValue(0)))
        .get();
    progress = {for (final p in prog) p.key: p};

    viewed = (await (db.select(db.viewedRows)
              ..where((r) => r.profileId.equals(pid)))
            .map((v) => '$pid:${v.kind}:${v.itemId}')
            .get())
        .toSet();
  }

  // ---------------------------------------------------------------- playlists

  Future<Playlist> addXtream(
      String name, String host, String user, String pass) async {
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final pl = Playlist(id: id, name: name, type: PlaylistType.xtream, host: host);
    await db.into(db.playlistRows).insert(PlaylistRowsCompanion.insert(
          id: id,
          name: name,
          kind: 'xtream',
          host: Value(host),
        ));
    await settings.saveCredentials(id, user, pass);
    playlists = [...playlists, pl];
    notifyListeners();
    await refresh(pl);
    return pl;
  }

  Future<Playlist> addM3u(String name, String m3uUrl, String? epgUrl) async {
    final id = 'pl_${DateTime.now().millisecondsSinceEpoch}';
    final pl = Playlist(
        id: id, name: name, type: PlaylistType.m3u, m3uUrl: m3uUrl, epgUrl: epgUrl);
    await db.into(db.playlistRows).insert(PlaylistRowsCompanion.insert(
          id: id,
          name: name,
          kind: 'm3u',
          m3uUrl: Value(m3uUrl),
          epgUrl: Value(epgUrl),
        ));
    playlists = [...playlists, pl];
    notifyListeners();
    await refresh(pl);
    return pl;
  }

  Future<void> deletePlaylist(String playlistId) async {
    await (db.delete(db.playlistRows)..where((r) => r.id.equals(playlistId))).go();
    await db.clearChannelsAndEpg(playlistId);
    await settings.deleteCredentials(playlistId);
    playlists.removeWhere((p) => p.id == playlistId);
    _channels.removeWhere((_, c) => c.playlistId == playlistId);
    notifyListeners();
    sync.schedulePush();
  }

  /// Re-downloads channels + EPG for a playlist.
  Future<void> refresh(Playlist pl) async {
    refreshError = null;
    notifyListeners();
    try {
      await db.clearChannelsAndEpg(pl.id);
      final list = pl.isXtream ? await _fetchXtream(pl) : await _fetchM3u(pl);
      await db.insertAllChannels(list.map(_toCompanion).toList());
      for (final c in list) {
        _channels[c.key] = ChannelRow(
          key: c.key,
          playlistId: c.playlistId,
          kind: c.kind.name,
          streamId: c.streamId,
          name: c.name,
          logoUrl: c.logoUrl,
          category: c.category,
          url: c.url,
          containerExt: c.containerExt,
          tvgId: c.tvgId,
          num: c.num,
          seriesId: c.seriesId,
          seriesName: c.seriesName,
          season: c.season,
          episode: c.episode,
        );
      }
      notifyListeners();
    } catch (e) {
      refreshError = e.toString();
      rethrow;
    }
  }

  Future<List<Channel>> _fetchXtream(Playlist pl) async {
    final cred = await settings.credentials(pl.id);
    if (cred == null) throw Exception('Keine Zugangsdaten für "${pl.name}"');
    return xtream.fetchAll(playlist: pl, user: cred.user, pass: cred.pass);
  }

  Future<List<Channel>> _fetchM3u(Playlist pl) async {
    final res = await _http.get(Uri.parse(pl.m3uUrl!));
    if (res.statusCode != 200) {
      throw Exception('Playlist-Download fehlgeschlagen (HTTP ${res.statusCode})');
    }
    final channels = M3uParser.parse(playlist: pl, body: res.body);
    if (pl.epgUrl != null && pl.epgUrl!.isNotEmpty) {
      try {
        final epgRes = await _http.get(Uri.parse(pl.epgUrl!));
        if (epgRes.statusCode == 200) {
          final entries = XmltvParser.parse(utf8.decode(epgRes.bodyBytes));
          await _storeEpg(pl, channels, entries);
        }
      } catch (e) {
        debugPrint('EPG-Load fehlgeschlagen: $e');
      }
    }
    return channels;
  }

  Future<void> _storeEpg(
      Playlist pl, List<Channel> channels, List<EpgEntry> entries) async {
    final byTvgId = <String, String>{};
    final byName = <String, String>{};
    for (final c in channels) {
      final tvg = c.tvgId ?? M3uParser.urlItemId(c.url);
      byTvgId[tvg] = c.key;
      byName[c.name.toLowerCase().trim()] = c.key;
    }

    final rows = <EpgRowsCompanion>[];
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 3));
    for (final e in entries) {
      if (e.stop.isBefore(now) || e.start.isAfter(horizon)) continue;
      final key = byTvgId[e.channelTvgId] ?? byName[e.channelTvgId.toLowerCase()];
      if (key == null) continue;
      rows.add(EpgRowsCompanion.insert(
        key: '${pl.id}:${e.channelTvgId}:${e.start.millisecondsSinceEpoch}',
        playlistId: pl.id,
        channelTvgId: e.channelTvgId,
        channelKey: key,
        start: e.start,
        stop: e.stop,
        title: e.title,
        desc: Value(e.desc),
      ));
    }
    await db.insertAllEpg(rows);
    _epgCache.clear();
  }

  ChannelRowsCompanion _toCompanion(Channel c) => ChannelRowsCompanion.insert(
        key: c.key,
        playlistId: c.playlistId,
        kind: c.kind.name,
        streamId: Value(c.streamId),
        name: c.name,
        logoUrl: Value(c.logoUrl),
        category: Value(c.category),
        url: c.url,
        containerExt: Value(c.containerExt),
        tvgId: Value(c.tvgId),
        num: Value(c.num),
        seriesId: Value(c.seriesId),
        seriesName: Value(c.seriesName),
        season: Value(c.season),
        episode: Value(c.episode),
      );

  // ---------------------------------------------------------------- channels

  bool _isHidden(String channelKey) =>
      favorites['${activeProfileId}:$channelKey:hidden'] != null;

  List<ChannelRow> channels(MediaKind kind) {
    bool excluded(ChannelRow c) =>
        _isHidden(c.key) ||
        (c.category.isNotEmpty && isCategoryLocked(c.playlistId, c.category));
    return _channels.values
        .where((c) => c.kind == kind.name)
        .where((c) => !excluded(c))
        .toList()
      ..sort((a, b) => (a.num ?? 1 << 30).compareTo(b.num ?? 1 << 30));
  }

  ChannelRow? channelByKey(String key) => _channels[key];

  List<String> categories(MediaKind kind) {
    final set = <String>{};
    for (final c in _channels.values) {
      if (c.kind == kind.name) set.add(c.category);
    }
    return set.toList()..sort();
  }

  // ---------------------------------------------------------------- EPG

  Future<List<EpgEntry>> epgForChannel(ChannelRow channel) async {
    final cached = _epgCache[channel.key];
    if (cached != null) return cached;
    final rows = await (db.select(db.epgRows)
          ..where((r) => r.channelKey.equals(channel.key)))
        .get();
    final entries = rows
        .map((e) => EpgEntry(
              channelTvgId: e.channelTvgId,
              start: e.start,
              stop: e.stop,
              title: e.title,
              desc: e.desc,
            ))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    _epgCache[channel.key] = entries;
    return entries;
  }

  // ---------------------------------------------------------------- favorites / hide / lock

  bool isFavorite(String channelKey) =>
      favorites['${activeProfileId}:$channelKey:favorite'] != null;

  Future<void> toggleFavorite(ChannelRow c) async =>
      _toggleMarker(c, 'favorite');

  Future<void> toggleHidden(ChannelRow c) async =>
      _toggleMarker(c, 'hidden');

  Future<void> _toggleMarker(ChannelRow c, String state) async {
    final pid = activeProfileId;
    if (pid == null) return;
    final key = '$pid:${c.key}:$state';
    if (favorites.containsKey(key)) {
      favorites.remove(key);
      await (db.delete(db.favoriteRows)..where((r) => r.key.equals(key))).go();
    } else {
      final row = FavoriteRow(
        key: key,
        profileId: pid,
        playlistId: c.playlistId,
        kind: c.kind,
        itemId: _itemIdOf(c),
        title: c.name,
        logoUrl: c.logoUrl,
        state: state,
        updatedAt: DateTime.now(),
      );
      favorites[key] = row;
      await db
          .into(db.favoriteRows)
          .insertOnConflictUpdate(FavoriteRowsCompanion.insert(
            key: key,
            profileId: pid,
            playlistId: Value(c.playlistId),
            kind: c.kind,
            itemId: row.itemId,
            title: row.title,
            logoUrl: Value(c.logoUrl),
            state: state,
            updatedAt: Value(row.updatedAt),
          ));
    }
    notifyListeners();
    sync.schedulePush();
  }

  List<ChannelRow> favoriteChannels() {
    return favorites.values
        .where((f) => f.state == 'favorite')
        .map((f) => _channels['${f.playlistId}:${f.kind}:${f.itemId}'] ??
            _lookupByItemId(f))
        .whereType<ChannelRow>()
        .toList();
  }

  ChannelRow? _lookupByItemId(FavoriteRow f) {
    for (final c in _channels.values) {
      if (c.kind == f.kind && _itemIdOf(c) == f.itemId) return c;
    }
    return null;
  }

  String _itemIdOf(ChannelRow c) => c.key.substring(c.key.lastIndexOf(':') + 1);

  Future<void> toggleCategoryLock(String playlistId, String category) async {
    final id = '$playlistId:$category';
    if (!lockedCategories.add(id)) lockedCategories.remove(id);
    await settings.set('locked_categories', jsonEncode(lockedCategories.toList()));
    notifyListeners();
  }

  bool isCategoryLocked(String playlistId, String category) =>
      lockedCategories.contains('$playlistId:$category');

  // ---------------------------------------------------------------- progress / views

  WatchProgress? progressFor(String channelKey) {
    final p = progress['${activeProfileId}:$channelKey'];
    if (p == null) return null;
    return WatchProgress(
      key: p.key,
      profileId: p.profileId,
      playlistId: p.playlistId,
      kind: MediaKind.values.firstWhere((k) => k.name == p.kind),
      itemId: p.itemId,
      title: p.title,
      positionMs: p.positionMs,
      durationMs: p.durationMs,
      updatedAt: p.updatedAt,
    );
  }

  Future<void> saveProgress(ChannelRow c, int positionMs, int durationMs) async {
    final pid = activeProfileId;
    if (pid == null) return;
    final key = '$pid:${c.key}';
    final row = ProgressRow(
      key: key,
      profileId: pid,
      playlistId: c.playlistId,
      kind: c.kind,
      itemId: _itemIdOf(c),
      title: c.name,
      positionMs: positionMs,
      durationMs: durationMs,
      updatedAt: DateTime.now(),
    );
    progress[key] = row;
    await db
        .into(db.progressRows)
        .insertOnConflictUpdate(ProgressRowsCompanion.insert(
          key: key,
          profileId: pid,
          playlistId: Value(c.playlistId),
          kind: c.kind,
          itemId: row.itemId,
          title: c.name,
          positionMs: Value(positionMs),
          durationMs: Value(durationMs),
          updatedAt: Value(row.updatedAt),
        ));
    if (durationMs > 0 && positionMs >= durationMs - 5000) {
      await markViewed(c);
    }
    sync.schedulePush();
  }

  List<WatchProgress> continueWatching() {
    bool wanted(ProgressRow p) =>
        p.kind != MediaKind.live.name &&
        p.durationMs > 0 &&
        p.positionMs / p.durationMs < 0.95;
    return progress.values
        .where(wanted)
        .map((p) => WatchProgress(
              key: p.key,
              profileId: p.profileId,
              playlistId: p.playlistId,
              kind: MediaKind.values.firstWhere((k) => k.name == p.kind),
              itemId: p.itemId,
              title: p.title,
              positionMs: p.positionMs,
              durationMs: p.durationMs,
              updatedAt: p.updatedAt,
            ))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> markViewed(ChannelRow c) async {
    final pid = activeProfileId;
    if (pid == null) return;
    final itemId = _itemIdOf(c);
    final id = '$pid:${c.kind}:$itemId';
    viewed.add(id);
    await db.into(db.viewedRows).insertOnConflictUpdate(
          ViewedRowsCompanion.insert(
            key: id,
            profileId: pid,
            kind: c.kind,
            itemId: itemId,
            updatedAt: Value(DateTime.now()),
          ),
        );
    sync.schedulePush();
  }

  bool isViewed(ChannelRow c) =>
      viewed.contains('${activeProfileId}:${c.kind}:${_itemIdOf(c)}');

  // ---------------------------------------------------------------- search / series

  List<ChannelRow> search(String term) {
    if (term.trim().length < 2) return const [];
    final q = term.trim().toLowerCase();
    return _channels.values
        .where((c) => c.name.toLowerCase().contains(q))
        .take(100)
        .toList();
  }

  List<ChannelRow> episodesOf(ChannelRow series) {
    if (series.seriesId == null) return [series];
    return _channels.values
        .where((c) => c.seriesId == series.seriesId)
        .toList()
      ..sort((a, b) {
        final s = (a.season ?? 0).compareTo(b.season ?? 0);
        return s != 0 ? s : (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
  }

  @override
  void dispose() {
    _http.close();
    unawaited(sync.dispose());
    super.dispose();
  }
}
