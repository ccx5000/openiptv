import 'package:flutter/material.dart';

import '../core/database/database.dart' as db;

/// Shared design tokens + building blocks for the "Canvas Noir" UI:
/// a neutral, near-black canvas where artwork carries the color and a
/// single warm accent is used with restraint.

class AppPalette {
  static const bg = Color(0xFF0A0A0B);
  static const surface = Color(0xFF161617);
  static const surfaceHi = Color(0xFF202022);
  static const navBg = Color(0xCC0A0A0B);
  static const field = Color(0xFF1D1D1F);
  static const hairline = Color(0xFF2A2A2E);
  static const accent = Color(0xFFE8A33D);
  static const accentDeep = Color(0xFFC87F1E);
  static const accent2 = Color(0xFFFFD37E);
  static const live = Color(0xFFFF3B5C);
  static const text = Color(0xFFF5F5F7);
  static const textDim = Color(0xFFA1A1A6);
  static const textDim2 = Color(0xFF6C6C72);

  static const accentGradient = LinearGradient(
    colors: [accent, accentDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Colors.transparent, Color(0xB3000000)],
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
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 21,
                  letterSpacing: -0.5,
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
  final bool wide;

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
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = title ?? channel!.name;
    final logo = logoUrl ?? channel?.logoUrl;
    return Focus(
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppPalette.surface,
                      border: Border.all(
                        color: focused
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.0),
                        width: 2,
                      ),
                      boxShadow: [
                        if (focused)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppPalette.field,
                          child: logo == null || logo.isEmpty
                              ? const Icon(Icons.play_circle_outline_rounded,
                                  size: 34, color: AppPalette.textDim2)
                              : Image.network(
                                  logo,
                                  fit: wide ? BoxFit.cover : BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 34,
                                      color: AppPalette.textDim2),
                                ),
                        ),
                        if (badge != null)
                          Positioned(top: 8, left: 8, child: _Badge(badge!)),
                        if (selected)
                          const Positioned(
                            top: 7,
                            right: 7,
                            child: Icon(
                              Icons.star_rounded,
                              color: AppPalette.accent,
                              size: 20,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black)
                              ],
                            ),
                          ),
                        if (progress != null && progress! > 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 3,
                              alignment: Alignment.centerLeft,
                              color: Colors.white24,
                              child: FractionallySizedBox(
                                widthFactor: progress!.clamp(0.0, 1.0),
                                child: const ColoredBox(
                                    color: AppPalette.accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: focused ? AppPalette.text : AppPalette.textDim,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppPalette.textDim2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Giant numbered tile, ranking-row style.
class Top10Tile extends StatelessWidget {
  final int rank;
  final db.ChannelRow? channel;
  final String? title;
  final String? logoUrl;
  final VoidCallback? onTap;

  const Top10Tile({
    super.key,
    required this.rank,
    this.channel,
    this.title,
    this.logoUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = title ?? (channel?.name ?? '');
    return Focus(
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: focused ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: rank == 10 ? 96 : 116,
                    height: 0.85,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -12,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppPalette.surface,
                      border: Border.all(
                        color: focused
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.0),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: AppPalette.field,
                          child: logoUrl == null || logoUrl!.isEmpty
                              ? const Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 30,
                                  color: AppPalette.textDim2,
                                )
                              : Image.network(
                                  logoUrl!,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.play_circle_outline_rounded,
                                      size: 30,
                                      color: AppPalette.textDim2),
                                ),
                        ),
                        Positioned(
                          left: 6,
                          right: 6,
                          bottom: 6,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black)
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    final isLive = text.toUpperCase() == 'LIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isLive ? AppPalette.live : Colors.black54,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Full-bleed, border-less billboard that fades into the canvas.
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
    final heroWidth = width - (width >= 900 ? 76 : 0);
    final height = (heroWidth / 1.9).clamp(240.0, 460.0);

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: AppPalette.field,
            child: logoUrl == null || logoUrl!.isEmpty
                ? Center(
                    child: Icon(
                      Icons.play_circle_outline_rounded,
                      size: 84,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  )
                : Image.network(
                    logoUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 84,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xCC0A0A0B),
                  Color(0x660A0A0B),
                  Color(0x1A0A0A0B)
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0x990A0A0B),
                  Color(0xFF0A0A0B)
                ],
                stops: [0.45, 0.8, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: AppPalette.accent,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.05,
                    shadows: [Shadow(blurRadius: 18, color: Colors.black)],
                  ),
                ),
                if (progress != null && progress! > 0) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 220,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Container(
                        height: 3,
                        alignment: Alignment.centerLeft,
                        color: Colors.white24,
                        child: FractionallySizedBox(
                          widthFactor: progress!.clamp(0.0, 1.0),
                          child: const ColoredBox(color: AppPalette.accent),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _PlayPill(onPressed: onPlay),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White, fully-rounded primary CTA (the only white button in the app).
class _PlayPill extends StatelessWidget {
  final VoidCallback? onPressed;
  const _PlayPill({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, size: 24, color: Colors.black),
              SizedBox(width: 6),
              Text(
                'Abspielen',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal text-tab category selector with a thin accent underline.
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
        padding: const EdgeInsets.only(right: 4),
        child: InkWell(
          onTap: () => onSelect(c),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(
                bottom: BorderSide(
                  width: 2.5,
                  color: active
                      ? AppPalette.accent
                      : Colors.white.withValues(alpha: 0.0),
                ),
              ),
            ),
            child: Text(
              c ?? allLabel,
              style: TextStyle(
                fontSize: 13,
                height: 1.0,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppPalette.text : AppPalette.textDim2,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
          Icon(icon, size: 46, color: AppPalette.textDim2),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppPalette.text,
            ),
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppPalette.textDim2, height: 1.4),
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
