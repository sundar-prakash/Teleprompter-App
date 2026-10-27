import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/domain/services/text_stats.dart';

void main() {
  test('counts words, characters (by code point) and paragraphs', () {
    final s = TextStats.of('Hello  world\n\nनमस्ते 😀');
    expect(s.words, 4);
    expect(s.paragraphs, 2);
    expect(TextStats.of('😀').characters, 1);
  });

  test('empty text', () {
    final s = TextStats.of('  \n ');
    expect((s.words, s.characters, s.paragraphs), (0, 0, 0));
  });

  test('duration estimate', () {
    final text = List.filled(300, 'w').join(' ');
    expect(TextStats.of(text).estimatedDuration(), const Duration(minutes: 2));
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 65)), '1:05');
    expect(formatDuration(const Duration(hours: 1, seconds: 5)), '1:00:05');
  });
}
