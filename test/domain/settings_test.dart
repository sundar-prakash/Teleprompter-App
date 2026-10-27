import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/domain/models/teleprompter_settings.dart';

void main() {
  test('json round trip', () {
    final s = const TeleprompterSettings().copyWith(
      fontSize: 60,
      mirrorHorizontal: true,
      fontFamily: 'serif',
      align: ReadAlign.left,
    );
    final back = TeleprompterSettings.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('pace is in seconds per line and independent of font size', () {
    const a = TeleprompterSettings(
      fontSize: 40,
      lineHeight: 1.5,
      secondsPerLine: 2,
    );
    expect(a.pixelsPerSecond, 30);
    expect(a.copyWith(fontSize: 80).pixelsPerSecond, 60);
    expect(TeleprompterSettings.nudgeSeconds(1.5, faster: true), 1.4);
    expect(TeleprompterSettings.nudgeSeconds(4, faster: false), 4.5);
    expect(TeleprompterSettings.nudgeSeconds(0.3, faster: true), 0.3);
  });

  test('copyWith can clear fontFamily to null', () {
    final s = const TeleprompterSettings(fontFamily: 'serif')
        .copyWith(fontFamily: null);
    expect(s.fontFamily, isNull);
  });

  test('fromJson clamps out-of-range values and ignores garbage', () {
    final s = TeleprompterSettings.fromJson({
      'fontSize': 9999,
      'secondsPerLine': -5,
      'align': 'bogus',
    });
    expect(s.fontSize, 200);
    expect(s.secondsPerLine, 0.3);
    expect(s.align, ReadAlign.center);
  });
}
