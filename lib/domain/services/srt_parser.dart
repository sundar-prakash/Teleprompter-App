class SrtCue {
  const SrtCue(this.index, this.start, this.end, this.text);
  final int index;
  final Duration start;
  final Duration end;
  final String text;
}

class SrtFormatException implements Exception {
  const SrtFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Parses SubRip (.srt). Tolerant of BOM, CRLF, missing indexes and `.` as the
/// millisecond separator. Throws [SrtFormatException] if no cue is found.
List<SrtCue> parseSrt(String input) {
  final text = input.replaceFirst('﻿', '').replaceAll('\r\n', '\n');
  final time = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );
  final cues = <SrtCue>[];
  for (final block in text.split(RegExp(r'\n{2,}'))) {
    final lines = block.trim().split('\n');
    final ti = lines.indexWhereTime(time);
    if (ti < 0) continue;
    final m = time.firstMatch(lines[ti])!;
    Duration d(int o) => Duration(
      hours: int.parse(m[o]!),
      minutes: int.parse(m[o + 1]!),
      seconds: int.parse(m[o + 2]!),
      milliseconds: int.parse(m[o + 3]!.padRight(3, '0')),
    );
    final body = lines
        .skip(ti + 1)
        .map((l) => l.replaceAll(RegExp(r'<[^>]+>|\{\\[^}]*\}'), '').trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
    if (body.isEmpty) continue;
    final idx = ti > 0 ? int.tryParse(lines[ti - 1].trim()) : null;
    cues.add(SrtCue(idx ?? cues.length + 1, d(1), d(5), body));
  }
  if (cues.isEmpty) {
    throw const SrtFormatException(
      'No subtitle cues were found. Is this a valid .srt file?',
    );
  }
  return cues;
}

/// Converts cues into continuous script text (one paragraph per cue).
String srtToContinuousText(List<SrtCue> cues) =>
    cues.map((c) => c.text.replaceAll('\n', ' ')).join('\n\n');

extension on List<String> {
  int indexWhereTime(RegExp r) => indexWhere(r.hasMatch);
}
