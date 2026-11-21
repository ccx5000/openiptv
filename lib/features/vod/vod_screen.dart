import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';
import '../../core/models/models.dart';
import '../player/player_screen.dart';

/// Movies & series browser with tabs + category filter.
class VodScreen extends StatefulWidget {
  const VodScreen({super.key});

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    context.watch<LibraryController>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Filme & Serien'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Filme'),
              Tab(text: 'Serien'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VodGrid(kind: MediaKind.vod, category: _category),
            _VodGrid(kind: MediaKind.series, category: _category),
          ],
        ),
      ),
    );
  }
}

class _VodGrid extends StatefulWidget {
  final MediaKind kind;
  final String? category;

  const _VodGrid({required this.kind, this.category});

  @override
  State<_VodGrid> createState() => _VodGridState();
}

class _VodGridState extends State<_VodGrid> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final categories =
        lib.categories(widget.kind).where((c) => c.isNotEmpty).toList();
    final current = _category ?? widget.category;
    final all = lib.channels(widget.kind);
    final items = current == null
        ? all
        : all.where((c) => c.category == current).toList();

    return Column(
      children: [
        const SizedBox(height: 8),
        CategoryChips(
          categories: categories,
          selected: current,
          allLabel: 'Alle Kategorien',
          onSelect: (v) => setState(() => _category = v),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  Icons.movie_creation_outlined,
                  'Keine Inhalte',
                  hint: 'Playlist hinzufügen oder Kategorie ändern.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        (constraints.maxWidth / 165).clamp(2, 8).floor();
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final c = items[i];
                        final isSeries = c.kind == MediaKind.series.name;
                        return PosterCard(
                          channel: c,
                          subtitle: c.category,
                          progress: lib.isViewed(c) ? 1.0 : null,
                          onTap: () {
                            if (isSeries) {
                              _openSeries(context, c);
                            } else {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    PlayerScreen(channelKey: c.key),
                              ));
                            }
                          },
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _openSeries(BuildContext context, c) async {
    final lib = context.read<LibraryController>();
    final episodes = lib.episodesOf(c);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: episodes.length,
            itemBuilder: (ctx, i) {
              final e = episodes[i];
              final label = [
                if (e.season != null) 'S${e.season}',
                if (e.episode != null) 'E${e.episode}',
                e.name,
              ].join(' · ');
              return ListTile(
                leading: Icon(
                  lib.isViewed(e)
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_outline_rounded,
                ),
                title: Text(label),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PlayerScreen(channelKey: e.key),
                  ));
                },
              );
            },
          ),
        );
      },
    );
  }
}
