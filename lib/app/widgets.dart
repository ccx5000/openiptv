import 'package:flutter/material.dart';

import '../core/database/database.dart' as db;

/// Shared building blocks: poster/list tiles, section headers, states.

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PosterCard extends StatelessWidget {
  final db.ChannelRow? channel;
  final String? title;
  final String? logoUrl;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onTap;
  final bool selected;

  const PosterCard({
    super.key,
    this.channel,
    this.title,
    this.logoUrl,
    this.subtitle,
    this.progress,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = title ?? channel!.name;
    final logo = logoUrl ?? channel?.logoUrl;
    return FocusableActionDetector(
      onShowFocusHighlight: (_) {},
      child: Focus(
        child: Builder(builder: (context) {
          final focused = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              scale: focused ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: Card(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: const Color(0xFF1B2130),
                            child: logo == null || logo.isEmpty
                                ? const Icon(Icons.tv_rounded, size: 40)
                                : Image.network(
                                    logo,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.tv_rounded, size: 40),
                                  ),
                          ),
                          if (progress != null && progress! > 0)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                              ),
                            ),
                          if (selected)
                            const Positioned(
                              top: 6,
                              right: 6,
                              child: Icon(Icons.star_rounded,
                                  color: Colors.amber),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity( 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;

  const EmptyState(this.icon, this.title, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity( 0.55)),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message,
) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK')),
      ],
    ),
  );
  return res ?? false;
}
