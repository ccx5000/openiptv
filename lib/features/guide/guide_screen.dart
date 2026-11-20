import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/database/database.dart' as db;
import '../../core/library_controller.dart';
import '../../core/models/models.dart';
import '../player/player_screen.dart';

/// EPG guide with a horizontal timeline ("TV Guide").
/// Left column = channel names; right = programmes on a
/// 3-pixel-per-minute grid, 3 hours of horizon.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  static const double pxPerMinute = 3.0;
  static const int hours = 3;

  late DateTime _start;
  Map<String, List<EpgEntry>> _epg = {};
  bool _epgLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final roundHour = now.minute < 30 ? now.hour : now.hour + 1;
    _start = DateTime(now.year, now.month, now.day, roundHour);
    _loadEpg();
  }

  Future<void> _loadEpg() async {
    final lib = context.read<LibraryController>();
    setState(() => _epgLoading = true);
    final channels = lib.channels(MediaKind.live);
    final map = <String, List<EpgEntry>>{};
    for (final c in channels.take(400)) {
      map[c.key] = await lib.epgForChannel(c);
    }
    if (!mounted) return;
    setState(() {
      _epg = map;
      _epgLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryController>();
    final channels = lib.channels(MediaKind.live).take(400).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text('TV Guide',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _epgLoading ? null : _loadEpg,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Aktualisieren'),
              ),
              if (_epgLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: Row(
            children: [
              const SizedBox(width: 120),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: 60.0 * pxPerMinute * hours + 200,
                    child: Row(
                      children: [
                        for (var h = 0; h <= hours; h++)
                          SizedBox(
                            width: 60.0 * pxPerMinute,
                            child: Text(
                              DateFormat.Hm().format(
                                  _start.add(Duration(hours: h))),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white60),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: channels.isEmpty
              ? const Center(child: Text('Keine Kanäle / kein EPG geladen'))
              : ListView.builder(
                  itemCount: channels.length,
                  itemBuilder: (context, i) {
                    final c = channels[i];
                    return _ChannelGuideRow(
                      channel: c,
                      entries: _epg[c.key] ?? const <EpgEntry>[],
                      start: _start,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ChannelGuideRow extends StatelessWidget {
  final db.ChannelRow channel;
  final List<EpgEntry> entries;
  final DateTime start;

  const _ChannelGuideRow({
    required this.channel,
    required this.entries,
    required this.start,
  });

  @override
  Widget build(BuildContext context) {
    final end =
        start.add(const Duration(hours: GuideScreen.hours));

    double widthOf(EpgEntry e) {
      final s = e.start.isBefore(start) ? start : e.start;
      final stop = e.stop.isAfter(end) ? end : e.stop;
      return (stop.difference(s).inMinutes * GuideScreen.pxPerMinute)
          .clamp(30.0, 100000.0)
          .toDouble();
    }

    double offsetOf(EpgEntry e) {
      if (e.start.isBefore(start)) return 0;
      return e.start.difference(start).inMinutes * GuideScreen.pxPerMinute;
    }

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                channel.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlayerScreen(channelKey: channel.key),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: 60.0 * GuideScreen.pxPerMinute * GuideScreen.hours + 200,
                  height: 56,
                  child: Stack(
                    children: [
                      for (final e in entries)
                        Positioned(
                          left: offsetOf(e),
                          top: 6,
                          child: _ProgrammeChip(
                            entry: e,
                            width: widthOf(e),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeChip extends StatelessWidget {
  final EpgEntry entry;
  final double width;

  const _ProgrammeChip({required this.entry, required this.width});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = entry.start.isBefore(now) && entry.stop.isAfter(now);
    return Container(
      height: 44,
      width: width,
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: current ? const Color(0xFF4F8CFF) : const Color(0xFF1B2130),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        entry.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
