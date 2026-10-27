class TextStats {
  const TextStats(this.words, this.characters, this.paragraphs);
  final int words;
  final int characters;
  final int paragraphs;

  Duration estimatedDuration({int wordsPerMinute = 150}) =>
      Duration(seconds: (words / wordsPerMinute * 60).round());

  factory TextStats.of(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const TextStats(0, 0, 0);
    return TextStats(
      trimmed.split(RegExp(r'\s+')).length,
      trimmed.runes.length,
      splitParagraphs(trimmed).length,
    );
  }
}

/// Splits a script into display paragraphs. Blank lines separate paragraphs;
/// single newlines are preserved inside a paragraph as hard line breaks.
List<String> splitParagraphs(String text) => text
    .replaceAll('\r\n', '\n')
    .split(RegExp(r'\n\s*\n'))
    .map((p) => p.trim())
    .where((p) => p.isNotEmpty)
    .toList();

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}
