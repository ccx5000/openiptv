import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../models/models.dart';

/// Parses M3U / M3U8 playlists (extended #EXTINF format incl.
/// tvg-id, tvg-name, tvg-logo, group-title attributes).
class M3uParser {
  static final RegExp _attr = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

  static String urlItemId(String url) =>
      crypto.md5.convert(utf8.encode(url)).toString();

  /// Returns channels; order preserved as in the playlist.
  static List<Channel> parse({
    required Playlist playlist,
    required String body,
  }) {
    final channels = <Channel>[];
    final lines = const LineSplitter().convert(body);
    String? pendingName;
    String? tvgId;
    String? tvgName;
    String? tvgLogo;
    String? group;
    int num = 1;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        pendingName = line.split(',').skip(1).join(',').trim();
        final attrs = Map.fromEntries(
          _attr.allMatches(line).map((m) => MapEntry(m.group(1)!, m.group(2)!)),
        );
        tvgId = attrs['tvg-id'] ?? tvgId;
        tvgLogo = attrs['tvg-logo'] ?? tvgLogo;
        group = attrs['group-title'] ?? group;
        continue;
      }

      if (line.startsWith('#')) continue; // any other directive

      // Non-comment, non-directive line = stream URL.
      final name = (pendingName == null || pendingName.isEmpty)
          ? 'Channel $num'
          : pendingName;
      final url = line;
      final kind = _guessKind(url);
      channels.add(Channel(
        key: playlist.channelKey(kind, urlItemId(url)),
        playlistId: playlist.id,
        kind: kind,
        name: name,
        url: url,
        logoUrl: (tvgLogo == null || tvgLogo.isEmpty) ? null : tvgLogo,
        category: (group == null || group.isEmpty) ? 'Allgemein' : group,
        tvgId: (tvgId == null || tvgId.isEmpty) ? null : tvgId,
        containerExt: _extOf(url),
        num: num,
      ));
      num++;
      pendingName = null;
      tvgId = null;
      tvgName = null;
      tvgLogo = null;
      group = null;
    }
    return channels;
  }

  static MediaKind _guessKind(String url) {
    final u = url.toLowerCase();
    if (u.contains('.mp4') ||
        u.contains('.mkv') ||
        u.contains('.avi') ||
        u.contains('/movie/')) {
      return MediaKind.vod;
    }
    return MediaKind.live;
  }

  static String? _extOf(String url) {
    final i = url.lastIndexOf('.');
    if (i < 0 || i < url.length - 6) return null;
    final ext = url.substring(i + 1).toLowerCase();
    if (ext.contains('/') || ext.contains('?')) return null;
    return ext;
  }
}
