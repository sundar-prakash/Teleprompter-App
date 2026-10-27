import 'package:pdfrx/pdfrx.dart';

import 'import_result.dart';
import 'text_decoding.dart';

/// Extracts selectable text from a PDF. Scanned (image-only) PDFs have no text
/// layer; those are reported with guidance instead of returning empty text.
Future<({String text, List<String> warnings})> extractPdf(String path) async {
  await pdfrxFlutterInitialize();
  final PdfDocument doc;
  try {
    doc = await PdfDocument.openFile(path);
  } on PdfPasswordException {
    throw const ImportException(
      'This PDF is password-protected. Remove the password and try again.',
    );
  } catch (_) {
    throw const ImportException(
      'This PDF could not be opened. It may be corrupted.',
    );
  }
  try {
    final pages = <String>[];
    var empty = 0;
    for (final page in doc.pages) {
      final raw = await page.loadText();
      final t = raw?.fullText.trim() ?? '';
      if (t.isEmpty) {
        empty++;
      } else {
        pages.add(reflowPdfText(t));
      }
    }
    if (pages.isEmpty ||
        pages.join().replaceAll(RegExp(r'\s'), '').length < 20 * 1) {
      throw const ImportException(
        'This PDF appears to be scanned (it has no selectable text). '
        'Run it through an OCR tool (e.g. Google Drive "Open with Google Docs") and import the result.',
      );
    }
    return (
      text: pages.join('\n\n'),
      warnings: [
        if (empty > 0)
          '$empty of ${doc.pages.length} pages had no selectable text and were skipped.',
      ],
    );
  } finally {
    await doc.dispose();
  }
}

/// PDF text has a hard line break at every visual line. Rejoin wrapped lines
/// into paragraphs; keep a break after a short line that ends a sentence.
String reflowPdfText(String raw) {
  final lines = normalizeNewlines(raw)
      .split('\n')
      .map((l) => l.trim())
      .toList();
  final maxLen = lines.fold<int>(0, (m, l) => l.length > m ? l.length : m);
  final out = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.isEmpty) {
      out.write('\n\n');
      continue;
    }
    out.write(l);
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    if (next.isEmpty) continue;
    final endsSentence = RegExp(r'[.!?:"”)]$').hasMatch(l);
    final isShort = l.length < maxLen * 0.6;
    final bullet = RegExp(r'^([•\-*]|\d+[.)])\s').hasMatch(next);
    if ((endsSentence && isShort) || bullet) {
      out.write('\n\n');
    } else if (l.endsWith('-') && l.length > 1) {
      // hyphenated wrap: drop hyphen only when it joins lowercase fragments
      if (RegExp(r'[a-z]-$').hasMatch(l) && RegExp(r'^[a-z]').hasMatch(next)) {
        final s = out.toString();
        out
          ..clear()
          ..write(s.substring(0, s.length - 1));
      }
    } else {
      out.write(' ');
    }
  }
  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}
