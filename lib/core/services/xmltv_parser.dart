import 'package:xml/xml.dart';

import '../models/models.dart';

/// XMLTV (xmltv.dtd) parser — the universal EPG format behind M3U playlists.
///
/// Times look like "20240101120000 +0100" (see https://wiki.xmltv.org).
class XmltvParser {
  static final RegExp _ts =
      RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})');
  static final RegExp _offset = RegExp(r'([+-])(\d{2})(\d{2})$');

  static List<EpgEntry> parse(String body) {
    final doc = XmlDocument.parse(body);
    final out = <EpgEntry>[];
    for (final prog in doc.findAllElements('programme')) {
      final ch = prog.getAttribute('channel');
      final rawStart = prog.getAttribute('start');
      final rawStop = prog.getAttribute('stop');
      if (ch == null || rawStart == null || rawStop == null) continue;
      final start = _dateTime(rawStart);
      final stop = _dateTime(rawStop);
      if (start == null || stop == null) continue;
      out.add(EpgEntry(
        channelTvgId: ch,
        start: start,
        stop: stop,
        title: _textOf(prog, 'title'),
        desc: _textOf(prog, 'desc'),
      ));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  static String _textOf(XmlElement parent, String tag) {
    for (final e in parent.findElements(tag)) {
      return e.innerText.trim();
    }
    return '';
  }

  /// XMLTV stamps the offset (e.g. "... +0100"); we normalize to real UTC
  /// instants and let consumers display in local time.
  static DateTime? _dateTime(String raw) {
    final m = _ts.firstMatch(raw);
    if (m == null) return null;
    var utc = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
    final off = _offset.firstMatch(raw);
    if (off != null) {
      final hh = int.parse(off.group(2)!);
      final mm = int.parse(off.group(3)!);
      final delta = Duration(hours: hh, minutes: mm);
      utc = off.group(1) == '-' ? utc.add(delta) : utc.subtract(delta);
    }
    return utc.toLocal();
  }
}
