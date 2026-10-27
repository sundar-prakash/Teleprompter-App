import '../../domain/models/script.dart';
import '../../domain/services/srt_parser.dart';

class ImportResult {
  const ImportResult({
    required this.title,
    required this.text,
    required this.format,
    required this.fileName,
    this.cues = const [],
    this.warnings = const [],
  });

  final String title;

  /// Teleprompter-ready text (paragraphs separated by blank lines).
  final String text;
  final SourceFormat format;
  final String fileName;

  /// Non-empty only for SRT.
  final List<SrtCue> cues;
  final List<String> warnings;
}

/// Carries a user-presentable message.
class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
