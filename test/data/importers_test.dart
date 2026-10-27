import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/data/importers/docx_extractor.dart';
import 'package:teleprompter/data/importers/import_result.dart';
import 'package:teleprompter/data/importers/markdown_converter.dart';
import 'package:teleprompter/data/importers/pdf_extractor.dart'
    show reflowPdfText;
import 'package:teleprompter/data/importers/script_importer.dart';
import 'package:teleprompter/domain/models/script.dart';

Uint8List _docx(String bodyXml) {
  final xml =
      '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body>$bodyXml</w:body></w:document>';
  final a = Archive()
    ..addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(xml)));
  return Uint8List.fromList(ZipEncoder().encode(a));
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('imp'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  group('docx', () {
    test('paragraphs, lists, line breaks, unicode', () {
      final text = extractDocx(
        _docx(
          '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Intro</w:t></w:r></w:p>'
          '<w:p><w:r><w:t>Hello</w:t></w:r><w:r><w:br/></w:r><w:r><w:t>नमस्ते</w:t></w:r></w:p>'
          '<w:p/>'
          '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>one</w:t></w:r></w:p>'
          '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/></w:numPr></w:pPr><w:r><w:t>two</w:t></w:r></w:p>',
        ),
      );
      expect(text, 'Intro\n\nHello\nनमस्ते\n\n• one\n• two');
    });

    test('corrupted file gives a readable error', () {
      expect(
        () => extractDocx(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<ImportException>()),
      );
    });
  });

  test('markdown strips markup, keeps structure', () {
    final t = markdownToScript(
      '# Title\n\nSome **bold** and [a link](http://x) text.\n\n- item\n- item2\n\n```\ncode\n```',
    );
    expect(
      t,
      'Title\n\nSome bold and a link text.\n\n• item\n• item2\n\ncode'
          .replaceAll('\n\ncode', '\n\ncode')
          .replaceAll('item2\n\ncode', 'item2\n\ncode'),
    );
  });

  test('pdf reflow joins wrapped lines but keeps short sentence-ending lines as breaks', () {
    const raw =
        'This is a long line of text that wraps\nonto the next line and ends here.\nShort end.\nNext paragraph begins here';
    final out = reflowPdfText(raw);
    expect(out.split('\n\n').length, 2);
    expect(
      out.startsWith(
        'This is a long line of text that wraps onto the next line',
      ),
      isTrue,
    );
  });

  group('importScriptFile', () {
    test('txt with UTF-16 BOM and CRLF', () async {
      final units = 'Line one\r\n\r\nLine two'.codeUnits;
      final bytes = [
        0xFF,
        0xFE,
        for (final u in units) ...[u & 0xFF, u >> 8],
      ];
      final r = await importScriptFile(write('a.txt', bytes).path);
      expect(r.text, 'Line one\n\nLine two');
      expect(r.format, SourceFormat.txt);
    });

    test('srt keeps cues and builds continuous text', () async {
      final r = await importScriptFile(
        write(
          's.srt',
          utf8.encode(
            '1\n00:00:01,000 --> 00:00:02,000\nHi\n\n2\n00:00:03,000 --> 00:00:04,000\nThere\n',
          ),
        ).path,
      );
      expect(r.cues, hasLength(2));
      expect(r.text, 'Hi\n\nThere');
    });

    test('docx via file', () async {
      final r = await importScriptFile(
        write('d.docx', _docx('<w:p><w:r><w:t>Hi</w:t></w:r></w:p>')).path,
      );
      expect(r.text, 'Hi');
      expect(r.format, SourceFormat.docx);
    });

    test('.doc, unsupported, empty and bad srt produce clear errors', () async {
      Future<String> msg(String name, List<int> b) async {
        try {
          await importScriptFile(write(name, b).path);
        } on ImportException catch (e) {
          return e.message;
        }
        return 'no error';
      }

      expect(await msg('old.doc', [1, 2]), contains('.docx'));
      expect(await msg('x.exe', [1]), contains('not supported'));
      expect(await msg('e.txt', []), contains('empty'));
      expect(
        await msg('bad.srt', utf8.encode('nothing here')),
        contains('No subtitle cues'),
      );
      expect(await msg('bad.docx', [1, 2, 3, 4]), contains('docx'));
    });
  });
}
