/// Shared domain models.

enum MediaKind { live, vod, series }

enum PlaylistType { xtream, m3u }

class Playlist {
  final String id;
  final String name;
  final PlaylistType type;
  final String? host;
  final String? m3uUrl;
  final String? epgUrl;

  const Playlist({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.m3uUrl,
    this.epgUrl,
  });

  bool get isXtream => type == PlaylistType.xtream;

  /// Stable identity used for sync keys.
  String channelKey(MediaKind kind, String itemId) => '$id:$kind:$itemId';
}

class Channel {
  final String key;
  final String playlistId;
  final MediaKind kind;
  final int? streamId;
  final String name;
  final String? logoUrl;
  final String category;
  final String url;
  final String? containerExt;
  final String? tvgId;
  final int? num;
  final String? seriesId;
  final String? seriesName;
  final int? season;
  final int? episode;

  const Channel({
    required this.key,
    required this.playlistId,
    required this.kind,
    required this.name,
    required this.url,
    this.streamId,
    this.logoUrl,
    this.category = '',
    this.containerExt,
    this.tvgId,
    this.num,
    this.seriesId,
    this.seriesName,
    this.season,
    this.episode,
  });
}

class EpgEntry {
  final String channelTvgId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? desc;

  const EpgEntry({
    required this.channelTvgId,
    required this.start,
    required this.stop,
    required this.title,
    this.desc,
  });

  bool get now => start.isBefore(DateTime.now()) && stop.isAfter(DateTime.now());
}

/// A household profile inside one account (Netflix-style multi user).
class UserProfile {
  final String id;
  final String name;
  final String avatarColor;
  final bool isKids;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarColor,
    required this.isKids,
  });
}

class FavoriteItem {
  final String key;
  final String profileId;
  final String? playlistId;
  final MediaKind kind;
  final String itemId;
  final String title;
  final String? logoUrl;
  final String state; // favorite | hidden | locked

  const FavoriteItem({
    required this.key,
    required this.profileId,
    this.playlistId,
    required this.kind,
    required this.itemId,
    required this.title,
    this.logoUrl,
    required this.state,
  });
}

class WatchProgress {
  final String key;
  final String profileId;
  final String? playlistId;
  final MediaKind kind;
  final String itemId;
  final String title;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  const WatchProgress({
    required this.key,
    required this.profileId,
    this.playlistId,
    required this.kind,
    required this.itemId,
    required this.title,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  double get fraction =>
      durationMs <= 0 ? 0.0 : (positionMs / durationMs).clamp(0.0, 1.0);
}
