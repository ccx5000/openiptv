import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';
import '../../core/database/database.dart' as db;
import '../../core/models/models.dart';
import '../player/player_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final continueWatching = lib.continueWatching();
    final favorites = lib.favoriteChannels();
    final live = lib.channels(MediaKind.live);
    final movies = lib.channels(MediaKind.vod);
    final series = lib.channels(MediaKind.series);
    final empty = continueWatching.isEmpty &&
        favorites.isEmpty &&
        live.isEmpty &&
        movies.isEmpty &&
        series.isEmpty;

    return lib.loadingLibrary
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : empty
            ? const Padding(
                padding: EdgeInsets.only(top: 120),
                child: EmptyState(
                  Icons.add_circle_outline_rounded,
                  'Noch nichts da',
                  hint: 'Erst unter Einstellungen → Playlisten '
                      'eine Playlist hinzufügen.',
                ),
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Hero(continueWatching, favorites, live),
                  const SizedBox(height: 6),
                  if (continueWatching.isNotEmpty) ...[
                    const SectionHeader('Weiter schauen'),
                    _Rail(
                      height: 168,
                      items: continueWatching.map((p) {
                        final channel = lib.channelByKey(
                            p.key.substring(p.key.indexOf(':') + 1));
                        return _RailItem(
                          width: 236,
                          child: PosterCard(
                            wide: true,
                            title: p.title,
                            logoUrl: channel?.logoUrl,
                            subtitle: _remaining(p),
                            progress: p.durationMs <= 0
                                ? 0.0
                                : p.positionMs / p.durationMs,
                            onTap: channel == null
                                ? null
                                : () => _openPlayer(context, channel.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (favorites.isNotEmpty) ...[
                    const SectionHeader('Favoriten'),
                    _Rail(
                      height: 224,
                      items: [
                        for (final c in favorites)
                          _RailItem(
                            width: 138,
                            child: PosterCard(
                              channel: c,
                              selected: true,
                              onTap: () => _openPlayer(context, c.key),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (movies.isNotEmpty) ...[
                    const SectionHeader('Top 10 Filme'),
                    _Rail(
                      height: 200,
                      items: [
                        for (final (i, c) in movies.take(10).indexed)
                          _RailItem(
                            width: 196,
                            child: Top10Tile(
                              rank: i + 1,
                              channel: c,
                              logoUrl: c.logoUrl,
                              onTap: () => _openPlayer(context, c.key),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (live.isNotEmpty) ...[
                    const SectionHeader('Live TV'),
                    _Rail(
                      height: 168,
                      items: [
                        for (final c in live.take(30))
                          _RailItem(
                            width: 236,
                            child: PosterCard(
                              wide: true,
                              channel: c,
                              badge: 'LIVE',
                              onTap: () => _openPlayer(context, c.key),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (series.isNotEmpty) ...[
                    const SectionHeader('Serien'),
                    _Rail(
                      height: 224,
                      items: [
                        for (final c in series.take(30))
                          _RailItem(
                            width: 138,
                            child: PosterCard(
                              channel: c,
                              onTap: () => _openPlayer(context, c.key),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 36),
                ],
              );
  }

  void _openPlayer(BuildContext context, String key) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(channelKey: key)),
    );
  }

  String _remaining(p) {
    if (p.durationMs <= 0) return '';
    final left = Duration(milliseconds: p.durationMs - p.positionMs);
    return 'Noch ${left.inMinutes} Min.';
  }
}

class _Hero extends StatelessWidget {
  final List<WatchProgress> continueWatching;
  final List<db.ChannelRow> favorites;
  final List<db.ChannelRow> live;

  const _Hero(this.continueWatching, this.favorites, this.live);

  @override
  Widget build(BuildContext context) {
    final lib = context.read<LibraryController>();
    final p = continueWatching.isEmpty ? null : continueWatching.first;
    final heroChannel = p != null
        ? lib.channelByKey(p.key.substring(p.key.indexOf(':') + 1))
        : (favorites.isNotEmpty
            ? favorites.first
            : (live.isNotEmpty ? live.first : null));
    if (heroChannel == null) return const SizedBox(height: 8);

    return HeroBanner(
      channel: heroChannel,
      logoUrl: heroChannel.logoUrl,
      title: p?.title ?? heroChannel.name,
      subtitle: p != null
          ? 'Weiter schauen'
          : heroChannel.kind == 'live'
              ? 'Live · ${heroChannel.category}'
              : heroChannel.category,
      progress: p == null || p.durationMs <= 0
          ? null
          : p.positionMs / p.durationMs,
      onPlay: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => PlayerScreen(channelKey: heroChannel.key)),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final double height;
  final List<Widget> items;

  const _Rail({required this.height, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final double width;
  final Widget child;

  const _RailItem({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}
