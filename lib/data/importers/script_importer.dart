import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../domain/models/script.dart';
import '../../domain/services/srt_parser.dart';
import 'docx_extractor.dart';
import 'import_result.dart';
import 'markdown_converter.dart';
import 'pdf_extractor.dart';
import 'text_decoding.dart';

const supportedImportExtensions = [
  'pdf',
  'docx',
  'doc',
  'srt',
  'txt',
  'md',
  'markdown',
];

/// Imports [path] into teleprompter-ready text. Heavy parsing runs in a
/// background isolate so the UI never freezes on large files.
Future<ImportResult> importScriptFile(String path) async {
  final file = File(path);
  final name = p.basename(path);
  final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
  final title = p.basenameWithoutExtension(path);

  if (!supportedImportExtensions.contains(ext)) {
    throw ImportException(
      '".${ext.isEmpty ? '?' : ext}" files are not supported. Supported: PDF, DOCX, SRT, TXT, MD.',
    );
  }
  if (ext == 'doc') {
    throw const ImportException(
      'Legacy .doc files can\'t be read directly. Open it in Word or Google Docs, '
      'save as .docx, and import that file.',
    );
  }
  if (!await file.exists()) {
    throw const ImportException('The selected file could not be found.');
  }

  if (ext == 'pdf') {
    final r = await extractPdf(path);
    return ImportResult(
      title: title,
      text: r.text,
      format: SourceFormat.pdf,
      fileName: name,
      warnings: r.warnings,
    );
  }

  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } on FileSystemException catch (e) {
    throw ImportException(
      'The file could not be read: ${e.osError?.message ?? e.message}',
    );
  }
  if (bytes.isEmpty) throw const ImportException('The file is empty.');

  try {
    return await Isolate.run(() => _parse(ext, title, name, bytes));
  } on ImportException {
    rethrow;
  } on SrtFormatException catch (e) {
    throw ImportException(e.message);
  }
}

ImportResult _parse(String ext, String title, String name, Uint8List bytes) {
  switch (ext) {
    case 'docx':
      final t = extractDocx(bytes);
      if (t.trim().isEmpty) {
        throw const ImportException('The document contains no text.');
      }
      return ImportResult(
        title: title,
        text: t,
        format: SourceFormat.docx,
        fileName: name,
      );
    case 'srt':
      final cues = parseSrt(decodeText(bytes));
      return ImportResult(
        title: title,
        text: srtToContinuousText(cues),
        format: SourceFormat.srt,
        fileName: name,
        cues: cues,
      );
    case 'md' || 'markdown':
      final t = markdownToScript(normalizeNewlines(decodeText(bytes)));
      if (t.isEmpty) {
        throw const ImportException('The document contains no text.');
      }
      return ImportResult(
        title: title,
        text: t,
        format: SourceFormat.md,
        fileName: name,
      );
    default:
      final t = normalizeNewlines(decodeText(bytes)).trim();
      if (t.isEmpty) {
        throw const ImportException('The document contains no text.');
      }
      return ImportResult(
        title: title,
        text: t,
        format: SourceFormat.txt,
        fileName: name,
      );
  }
}
