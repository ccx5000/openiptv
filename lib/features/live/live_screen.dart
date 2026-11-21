import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';
import '../../core/models/models.dart';
import '../player/player_screen.dart';

/// Live-TV grid with category filter, favorite stars and hide action
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
        if (!widget.compact) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Row(
              children: [
                Text(
                  'Live TV',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                        letterSpacing: -0.7,
                      ),
                ),
                const Spacer(),
                if (current != null)
                  _LockChip(
                    locked: channels.isNotEmpty &&
                        lib.isCategoryLocked(
                            channels.first.playlistId, current),
                    onToggle: () async {
                      if (channels.isEmpty) return;
                      await lib.toggleCategoryLock(
                          channels.first.playlistId, current);
                    },
                  ),
              ],
            ),
          ),
          CategoryChips(
            categories: categories,
            selected: current,
            onSelect: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 10),
        ],
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, i) {
                      final c = channels[i];
                      return PosterCard(
                        channel: c,
                        badge: 'LIVE',
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

class _LockChip extends StatelessWidget {
  final bool locked;
  final Future<void> Function() onToggle;

  const _LockChip({required this.locked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          locked ? 'Kategorie entsperren' : 'Kategorie sperren (Kinofreundlich)',
      child: InkWell(
        onTap: () => onToggle(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: locked
                ? AppPalette.accent.withValues(alpha: 0.14)
                : AppPalette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: locked
                  ? AppPalette.accent.withValues(alpha: 0.5)
                  : AppPalette.hairline,
            ),
          ),
          child: Row(
            children: [
              Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 18,
                color: locked ? AppPalette.accent : AppPalette.textDim2,
              ),
              const SizedBox(width: 8),
              Text(
                locked ? 'Gesperrt' : 'Sperren',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
