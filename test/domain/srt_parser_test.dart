import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/domain/services/srt_parser.dart';

void main() {
  test('parses cues, BOM, CRLF, dot separators and strips tags', () {
    const src =
        '﻿1\r\n00:00:01,500 --> 00:00:03,000\r\n<i>Hello</i>\r\nworld\r\n\r\n'
        '2\r\n00:00:04.000 --> 00:00:05.250\r\nSecond\r\n';
    final cues = parseSrt(src);
    expect(cues, hasLength(2));
    expect(cues[0].start, const Duration(seconds: 1, milliseconds: 500));
    expect(cues[0].text, 'Hello\nworld');
    expect(cues[1].end, const Duration(seconds: 5, milliseconds: 250));
    expect(srtToContinuousText(cues), 'Hello world\n\nSecond');
  });

  test('throws a readable error when there are no cues', () {
    expect(
      () => parseSrt('just some text'),
      throwsA(isA<SrtFormatException>()),
    );
  });
}
