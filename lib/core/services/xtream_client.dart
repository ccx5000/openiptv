import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

/// Minimal Xtream Codes API client.
///
/// Endpoints used (standard player_api.php surface):
///   get_live_categories / get_live_streams
///   get_vod_categories  / get_vod_streams
///   get_series_categories / get_series / get_series_info
///   get_simple_data_table (EPG)
class XtreamClient {
  final http.Client _http = http.Client();

  Uri _api(Playlist p, Map<String, String> extra, String user, String pass) {
    return Uri.http(p.host!, '/player_api.php', {
      'username': user,
      'password': pass,
      ...extra,
    });
  }

  Future<dynamic> _json(
      Playlist p, String action, String user, String pass) async {
    final res = await _http.get(_api(p, {'action': action}, user, pass));
    if (res.statusCode != 200) {
      throw Exception('Xtream $action failed: HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Full library fetch with batched callbacks (lists can exceed 40k items).
  Future<List<Channel>> fetchAll({
    required Playlist playlist,
    required String user,
    required String pass,
    Future<void> Function(List<Channel> soFar)? onProgress,
  }) async {
    final cats = <String, String>{};
    Future<void> loadCats(String action) async {
      final data = await _json(playlist, action, user, pass);
      if (data is List) {
        for (final c in data) {
          cats[c['category_id'].toString()] =
              c['category_name']?.toString() ?? '';
        }
      }
    }

    await loadCats('get_live_categories');
    await loadCats('get_vod_categories');
    await loadCats('get_series_categories');

    final out = <Channel>[];
    Future<void> streams(
      String action,
      MediaKind kind,
      String Function(String id, Map<String, dynamic> raw) urlBuilder,
    ) async {
      final data = await _json(playlist, action, user, pass);
      if (data is! List) return;
      for (final raw in data) {
        final id =
            raw['stream_id']?.toString() ?? raw['series_id']?.toString();
        if (id == null) continue;
        out.add(Channel(
          key: playlist.channelKey(kind, id),
          playlistId: playlist.id,
          kind: kind,
          streamId: int.tryParse(id),
          name: raw['name']?.toString() ?? 'Unknown',
          logoUrl:
              raw['stream_icon']?.toString() ?? raw['cover']?.toString(),
          category: cats[raw['category_id']?.toString()] ?? '',
          url: urlBuilder(id, raw),
          containerExt: raw['container_extension']?.toString(),
          num: int.tryParse(raw['num']?.toString() ?? ''),
        ));
        if (onProgress != null && out.length % 500 == 0) {
          await onProgress(List<Channel>.from(out));
        }
      }
    }

    await streams('get_live_streams', MediaKind.live,
        (id, _) => liveUrl(playlist, user, pass, id));
    await streams('get_vod_streams', MediaKind.vod,
        (id, raw) => vodUrl(playlist, user, pass, id, raw['container_extension']?.toString() ?? 'mp4'));
    await streams('get_series', MediaKind.series, (_, __) => '');

    await onProgress?.call(out);
    return out;
  }

  /// Series detail: episodes flattened into pseudo channels.
  Future<List<Channel>> episodes({
    required Playlist playlist,
    required String user,
    required String pass,
    required String seriesId,
    required String seriesName,
  }) async {
    final data = await _json(playlist, 'get_series_info', user, pass);
    final seasons = data is Map ? data['episodes'] : null;
    final out = <Channel>[];
    if (seasons is Map) {
      seasons.forEach((_, list) {
        if (list is! List) return;
        for (final raw in list) {
          final id = raw['id']?.toString();
          if (id == null) continue;
          out.add(Channel(
            key: playlist.channelKey(MediaKind.vod, id),
            playlistId: playlist.id,
            kind: MediaKind.vod,
            streamId: int.tryParse(id),
            name: raw['title']?.toString() ?? seriesName,
            category: seriesName,
            url: seriesUrl(playlist, user, pass, id,
                raw['container_extension']?.toString() ?? 'mp4'),
            containerExt: raw['container_extension']?.toString(),
            seriesId: seriesId,
            seriesName: seriesName,
            season: int.tryParse(raw['season']?.toString() ?? ''),
            episode: int.tryParse(raw['episode_num']?.toString() ?? ''),
          ));
        }
      });
    }
    return out;
  }

  /// EPG for one stream via Xtream (fallback when no XMLTV is configured).
  Future<List<EpgEntry>> epgForStream({
    required Playlist playlist,
    required String user,
    required String pass,
    required int streamId,
  }) async {
    final data = await _json(
        playlist, 'get_simple_data_table&stream_id=$streamId', user, pass);
    final list = data is Map ? data['data'] : data;
    final out = <EpgEntry>[];
    if (list is List) {
      for (final raw in list) {
        final startMs = int.tryParse(raw['start']?.toString() ?? '');
        final stopMs = int.tryParse(raw['end']?.toString() ?? '');
        if (startMs == null || stopMs == null) continue;
        out.add(EpgEntry(
          channelTvgId: streamId.toString(),
          start: DateTime.fromMillisecondsSinceEpoch(startMs * 1000),
          stop: DateTime.fromMillisecondsSinceEpoch(stopMs * 1000),
          title: raw['title']?.toString() ?? '',
          desc: raw['description']?.toString(),
        ));
      }
    }
    return out;
  }

  String liveUrl(Playlist p, String user, String pass, String streamId,
          {String ext = 'm3u8'}) =>
      'http://${p.host}/live/$user/$pass/$streamId.$ext';

  String vodUrl(
          Playlist p, String user, String pass, String streamId, String ext) =>
      'http://${p.host}/movie/$user/$pass/$streamId.$ext';

  String seriesUrl(Playlist p, String user, String pass, String episodeId,
          String ext) =>
      'http://${p.host}/series/$user/$pass/$episodeId.$ext';
}
