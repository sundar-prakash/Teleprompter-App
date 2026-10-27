import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'import_result.dart';
import 'text_decoding.dart';

/// Extracts text from .docx (OOXML). Preserves paragraphs, headings (as their
/// own paragraphs), list bullets, tabs and line breaks, including table cells.
String extractDocx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const ImportException(
      'This file is not a valid .docx document (it may be corrupted, or be an old .doc renamed).',
    );
  }
  final entry = zip.findFile('word/document.xml');
  if (entry == null) {
    throw const ImportException(
      'No document body found. This may not be a .docx file, or it is corrupted or password-protected.',
    );
  }
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(
      decodeText(Uint8List.fromList(entry.content as List<int>)),
    );
  } on XmlException {
    throw const ImportException(
      'The document content could not be read (corrupted XML).',
    );
  }

  final blocks = <String>[];
  final list = <String>[];
  void flushList() {
    if (list.isNotEmpty) blocks.add(list.join('\n'));
    list.clear();
  }

  for (final p in doc.findAllElements('p', namespaceUri: '*')) {
    final text = _paragraphText(p).trimRight();
    if (text.trim().isEmpty) {
      flushList();
      continue;
    }
    final isList = p.findAllElements('numPr', namespaceUri: '*').isNotEmpty;
    if (isList) {
      list.add('• ${text.trimLeft()}');
    } else {
      flushList();
      blocks.add(text);
    }
  }
  flushList();
  return blocks.join('\n\n');
}

String _paragraphText(XmlElement p) {
  final b = StringBuffer();
  for (final n in p.descendants.whereType<XmlElement>()) {
    switch (n.name.local) {
      case 't':
        b.write(n.innerText);
      case 'tab':
        b.write(' ');
      case 'br' || 'cr':
        b.write('\n');
    }
  }
  return b.toString();
}
