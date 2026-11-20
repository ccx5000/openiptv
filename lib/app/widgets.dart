import 'package:flutter/material.dart';

import '../core/database/database.dart' as db;

/// Shared design tokens + building blocks for the cinematic dark UI.

class AppPalette {
  static const bg = Color(0xFF07080C);
  static const surface = Color(0xFF12151E);
  static const surfaceHi = Color(0xFF181C28);
  static const navBg = Color(0xFF0C0F16);
  static const field = Color(0xFF1A2030);
  static const accent = Color(0xFF4F8CFF);
  static const accent2 = Color(0xFF9A6CFF);
  static const text = Color(0xFFE9EDF5);
  static const textDim = Color(0xFF9AA3B5);
  static const textDim2 = Color(0xFF6B7488);

  static const accentGradient = LinearGradient(
    colors: [accent, accent2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Colors.transparent, Color(0xB307080C)],
    stops: [0.0, 0.55, 1.0],
  );
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: AppPalette.accentGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
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
  final String? badge;

  const PosterCard({
    super.key,
    this.channel,
    this.title,
    this.logoUrl,
    this.subtitle,
    this.progress,
    this.onTap,
    this.selected = false,
    this.badge,
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
              scale: focused ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: AppPalette.surface,
                  border: Border.all(
                    color: focused
                        ? AppPalette.accent.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.05),
                    width: focused ? 2 : 1,
                  ),
                  boxShadow: [
                    if (focused)
                      BoxShadow(
                        color: AppPalette.accent.withValues(alpha: 0.28),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppPalette.field,
                            child: logo == null || logo.isEmpty
                                ? const Icon(Icons.play_circle_outline_rounded,
                                    size: 38, color: AppPalette.textDim)
                                : Image.network(
                                    logo,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                            Icons.play_circle_outline_rounded,
                                            size: 38,
                                            color: AppPalette.textDim),
                                  ),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppPalette.cardGradient,
                            ),
                          ),
                          if (badge != null)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _Badge(badge!),
                            ),
                          if (selected)
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFC64A),
                                size: 20,
                                shadows: [
                                  Shadow(blurRadius: 8, color: Colors.black54)
                                ],
                              ),
                            ),
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 9,
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                height: 1.15,
                                shadows: [
                                  Shadow(blurRadius: 10, color: Colors.black)
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppPalette.textDim,
                          ),
                        ),
                      ),
                    if (progress != null && progress! > 0)
                      SizedBox(
                        height: 3,
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          valueColor:
                              const AlwaysStoppedAnimation(AppPalette.accent),
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

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    final live = text.toUpperCase() == 'LIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: live ? const Color(0xFFE5484D) : Colors.black54,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Big cinematic banner for a featured item (continue watching / favorite).
class HeroBanner extends StatelessWidget {
  final db.ChannelRow? channel;
  final String? logoUrl;
  final String title;
  final String? subtitle;
  final double? progress;
  final VoidCallback? onPlay;

  const HeroBanner({
    super.key,
    this.channel,
    this.logoUrl,
    required this.title,
    this.subtitle,
    this.progress,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final heroWidth = width - (width >= 900 ? 90 : 0);
    final height = (heroWidth / 2.4).clamp(200.0, 380.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppPalette.surface,
            child: logoUrl == null || logoUrl!.isEmpty
                ? Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      size: 84,
                      color: AppPalette.accent.withValues(alpha: 0.25),
                    ),
                  )
                : Image.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 84,
                        color: AppPalette.accent.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xF207080C), Color(0x9907080C), Color(0x3307080C)],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC07080C)],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                      color: AppPalette.accent.withValues(alpha: 0.95),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: const [
                          Shadow(blurRadius: 16, color: Colors.black)
                        ],
                      ),
                ),
                if (progress != null && progress! > 0) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(AppPalette.accent),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text('Abspielen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal pill selector for categories (replaces dropdowns).
class CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final String allLabel;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
    this.allLabel = 'Alle',
  });

  @override
  Widget build(BuildContext context) {
    final items = [null, ...categories];
    Widget chip(String? c) {
      final active = c == null ? selected == null : selected == c;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => onSelect(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              gradient: active ? AppPalette.accentGradient : null,
              color: active ? null : AppPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Text(
              c ?? allLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? Colors.white : AppPalette.textDim,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [for (final c in items) chip(c)],
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
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppPalette.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppPalette.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, size: 42, color: AppPalette.accent),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppPalette.textDim),
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
