import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/widgets.dart';
import '../../core/library_controller.dart';

/// media_kit based player with an overlay UI (info bar, play/pause,
/// seek bar for VOD, favourite toggle) and progress saving for
/// "continue watching" + cross-device sync.
class PlayerScreen extends StatefulWidget {
  final String channelKey;

  const PlayerScreen({super.key, required this.channelKey});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    WakelockPlus.enable();
  }

  Future<void> _open() async {
    final lib = context.read<LibraryController>();
    final c = lib.channelByKey(widget.channelKey);
    if (c == null) return;

    final isLive = c.kind == 'live';
    if (!isLive) {
      final p = lib.progressFor(c.key);
      if (p != null && p.positionMs > 30000) {
        await _player.open(Media(c.url, start: Duration(milliseconds: p.positionMs)));
      } else {
        await _player.open(Media(c.url));
      }
    } else {
      await _player.open(Media(c.url));
    }
    await _player.play();

    _positionSub = _player.stream.position.listen((pos) {
      final dur = _player.state.duration.inMilliseconds;
      if (dur > 0) {
        lib.saveProgress(c, pos.inMilliseconds, dur);
      }
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (!playing) WakelockPlus.disable();
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playingSub?.cancel();
    _controlsTimer?.cancel();
    WakelockPlus.disable();
    _player.dispose();
    super.dispose();
  }

  void _bumpControls() {
    setState(() => _showControls = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final c = lib.channelByKey(widget.channelKey);
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Kanal nicht gefunden')));
    }
    final isLive = c.kind == 'live';
    final fav = lib.isFavorite(c.key);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _bumpControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: _controller,
              controls: NoVideoControls,
            ),
            if (_showControls)
              _ControlsOverlay(
                title: c.name,
                playlist: c.playlistId,
                isLive: isLive,
                favorite: fav,
                player: _player,
                onToggleFavorite: () => lib.toggleFavorite(c),
                onHide: () async {
                  await lib.toggleHidden(c);
                  if (context.mounted) Navigator.of(context).pop();
                },
                onBackPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatefulWidget {
  final String title;
  final String playlist;
  final bool isLive;
  final bool favorite;
  final Player player;
  final VoidCallback onToggleFavorite;
  final VoidCallback onHide;
  final VoidCallback onBackPressed;

  const _ControlsOverlay({
    required this.title,
    required this.playlist,
    required this.isLive,
    required this.favorite,
    required this.player,
    required this.onToggleFavorite,
    required this.onHide,
    required this.onBackPressed,
  });

  @override
  State<_ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<_ControlsOverlay> {
  late bool _playing = true;

  @override
  void initState() {
    super.initState();
    widget.player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.14, 0.5, 0.86, 1.0],
          colors: [
            Color(0xD9000000),
            Colors.transparent,
            Colors.transparent,
            Colors.transparent,
            Color(0xD9000000),
          ],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onBackPressed,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.isLive)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: _LivePill(),
                  ),
                IconButton(
                  tooltip: widget.favorite
                      ? 'Favorit entfernen'
                      : 'Zu Favoriten hinzufügen',
                  onPressed: widget.onToggleFavorite,
                  icon: Icon(widget.favorite
                      ? Icons.star_rounded
                      : Icons.star_border_rounded),
                ),
                IconButton(
                  tooltip: 'Ausblenden (Content Manager)',
                  onPressed: widget.onHide,
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Center controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GlassButton(
                size: 58,
                icon: Icons.replay_10_rounded,
                onTap: () {
                  final target = widget.player.state.position -
                      const Duration(seconds: 10);
                  widget.player
                      .seek(target.isNegative ? Duration.zero : target);
                },
              ),
              const SizedBox(width: 26),
              _GlassButton(
                size: 82,
                icon: _playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                primary: true,
                onTap: () {
                  if (_playing) {
                    widget.player.pause();
                  } else {
                    widget.player.play();
                  }
                },
              ),
              const SizedBox(width: 26),
              _GlassButton(
                size: 58,
                icon: Icons.forward_10_rounded,
                onTap: () => widget.player.seek(const Duration(seconds: 10)),
              ),
            ],
          ),
          const Spacer(),
          // Bottom seek bar
          if (!widget.isLive)
            SafeArea(
              top: false,
              child: StreamBuilder<Duration>(
                stream: widget.player.stream.position,
                builder: (context, posSnap) {
                  return StreamBuilder<Duration>(
                    stream: widget.player.stream.duration,
                    builder: (context, durSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final dur = durSnap.data ?? Duration.zero;
                      return Row(
                        children: [
                          const SizedBox(width: 16),
                          Text(_fmt(pos)),
                          Expanded(
                            child: Slider(
                              value: dur.inMilliseconds <= 0
                                  ? 0
                                  : pos.inMilliseconds
                                      .clamp(0, dur.inMilliseconds)
                                      .toDouble(),
                              max: dur.inMilliseconds.toDouble(),
                              onChanged: (v) => widget.player
                                  .seek(Duration(milliseconds: v.toInt())),
                            ),
                          ),
                          Text(_fmt(dur)),
                          const SizedBox(width: 16),
                        ],
                      );
                    },
                  );
                },
              ),
            )
          else
            const SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Live-Stream — kein Spulen möglich',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final double size;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  const _GlassButton({
    required this.size,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary ? Colors.white : Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: primary
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 18),
        ],
      ),
      child: Icon(
        icon,
        size: size * 0.52,
        color: primary ? Colors.black : Colors.white,
      ),
    );
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: child,
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.live.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.live.withValues(alpha: 0.55)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFFE5484D)),
          SizedBox(width: 6),
          Text(
            'LIVE',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
}
