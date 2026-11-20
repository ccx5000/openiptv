import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';
import '../player/player_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final continueWatching = lib.continueWatching();
    final favorites = lib.favoriteChannels();

    return lib.loadingLibrary
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              const SectionHeader('Weiter schauen'),
              if (continueWatching.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Noch nichts angesehen — viel Spaß!'),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: continueWatching.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final p = continueWatching[i];
                      final channel = lib
                          .channelByKey(p.key.substring(p.key.indexOf(':') + 1));
                      return SizedBox(
                        width: 160,
                        child: PosterCard(
                          title: p.title,
                          logoUrl: channel?.logoUrl,
                          subtitle: _remaining(p),
                          progress: p.durationMs <= 0
                              ? 0.0
                              : p.positionMs / p.durationMs,
                          onTap: channel == null
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PlayerScreen(channelKey: channel.key),
                                    ),
                                  ),
                        ),
                      );
                    },
                  ),
                ),
              const SectionHeader('Favoriten'),
              favorites.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child:
                          Text('Noch keine Favoriten — Stern in Live TV antippen.'),
                    )
                  : SizedBox(
                      height: 210,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final c = favorites[i];
                          return SizedBox(
                            width: 160,
                            child: PosterCard(
                              channel: c,
                              subtitle: c.kind,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(channelKey: c.key),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 32),
            ],
          );
  }

  String _remaining(p) {
    if (p.durationMs <= 0) return '';
    final left = Duration(milliseconds: p.durationMs - p.positionMs);
    return 'Noch ${left.inMinutes} Min.';
  }
}
