import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';
import '../../core/models/models.dart';
import '../player/player_screen.dart';

/// Live-TV grid with category filter, favorite stars and hide action
/// (the SwiptV/UHF "content manager" pattern).
class LiveScreen extends StatefulWidget {
  final bool compact; // embedded home variant without own filter bar

  const LiveScreen({super.key, this.compact = false});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final categories =
        lib.categories(MediaKind.live).where((c) => c.isNotEmpty).toList();
    final current = _category ?? (widget.compact ? null : categories.firstOrNull);
    final all = lib.channels(MediaKind.live);
    final channels = current == null
        ? all.take(widget.compact ? 30 : all.length).toList()
        : all.where((c) => c.category == current).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text('Live TV',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 24),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: current,
                    hint: const Text('Alle Kategorien'),
                    icon: const Icon(Icons.filter_list_rounded),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Alle Kategorien')),
                      for (final c in categories)
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                ),
                if (current != null)
                  IconButton(
                    tooltip: 'Kategorie sperren (Parental Control)',
                    icon: Icon(
                      (channels.isNotEmpty &&
                              lib.isCategoryLocked(
                                  channels.first.playlistId, current))
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                    ),
                    onPressed: () async {
                      if (channels.isEmpty) return;
                      await lib.toggleCategoryLock(
                          channels.first.playlistId, current);
                    },
                  ),
              ],
            ),
          ),
        Expanded(
          child: channels.isEmpty
              ? const EmptyState(
                  Icons.tv_off_rounded,
                  'Keine Kanäle',
                  hint: 'Erst unter Einstellungen → Playlisten hinzufügen.',
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = (width / 170).clamp(2, 8).floor();
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, i) {
                      final c = channels[i];
                      return PosterCard(
                        channel: c,
                        subtitle: c.category,
                        selected: lib.isFavorite(c.key),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlayerScreen(channelKey: c.key),
                          ),
                        ),
                      );
                    },
                  );
                }),
        ),
      ],
    );
  }
}
