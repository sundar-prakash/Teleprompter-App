/// Converts Markdown to plain teleprompter text, keeping headings, lists and
/// paragraph structure but dropping markup symbols.
String markdownToScript(String md) {
  final out = <String>[];
  var inFence = false;
  for (var line in md.split('\n')) {
    if (line.trimLeft().startsWith('```') ||
        line.trimLeft().startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (!inFence) {
      line = line
          .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
          .replaceFirst(RegExp(r'^\s*>\s?'), '')
          .replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ')
          .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
          .replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m[2]!)
          .replaceAllMapped(
            RegExp(r'(?<![\w*])([*_])(?!\s)(.+?)(?<!\s)\1(?![\w*])'),
            (m) => m[2]!,
          )
          .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m[1]!);
      if (RegExp(r'^\s*([-*_]\s*){3,}$').hasMatch(line)) line = '';
    }
    out.add(line);
  }
  return out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
