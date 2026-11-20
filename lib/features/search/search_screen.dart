import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';
import '../player/player_screen.dart';

/// Global search across all channels/VOD/series of all playlists
/// (global search across playlists).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final results = lib.search(_term);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _controller,
            onChanged: (v) => setState(() => _term = v),
            onSubmitted: (v) => setState(() => _term = v),
            decoration: InputDecoration(
              hintText: 'Kanäle, Filme, Serien durchsuchen…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _term.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _term = '');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: _term.trim().length < 2
              ? const EmptyState(
                  Icons.search_rounded,
                  'Suche nach mindestens 2 Zeichen',
                )
              : results.isEmpty
                  ? const EmptyState(Icons.search_off_rounded, 'Nichts gefunden')
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return PosterCard(
                          channel: c,
                          subtitle: c.kind,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(channelKey: c.key),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
