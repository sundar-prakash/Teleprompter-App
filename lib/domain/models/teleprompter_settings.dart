import 'package:flutter/foundation.dart';

enum ReadAlign { left, center, right, justify }

enum ReadingMode { continuous, singleLine, paragraph, manual, subtitle }

@immutable
class TeleprompterSettings {
  const TeleprompterSettings({
    this.fontFamily,
    this.fontSize = 44,
    this.fontWeight = 500,
    this.italic = false,
    this.lineHeight = 1.5,
    this.letterSpacing = 0,
    this.paragraphSpacing = 24,
    this.align = ReadAlign.center,
    this.rtl = false,
    this.textColor = 0xFFFFFFFF,
    this.backgroundColor = 0xFF000000,
    this.mirrorHorizontal = false,
    this.flipVertical = false,
    this.readingWidth = 0.9,
    this.horizontalMargin = 16,
    this.guidePosition = 0.35,
    this.showGuide = true,
    this.secondsPerLine = 1.5,
    this.countdownSeconds = 3,
    this.autoHideControls = true,
    this.mode = ReadingMode.continuous,
    this.paragraphPause = 2,
    this.autoPauseEvery = 0,
    this.autoPauseFor = 5,
    this.pipPortrait = false,
    this.autoPip = false,
    this.pipFontScale = 0.6,
  });

  /// `null` means the platform default font.
  final String? fontFamily;
  final double fontSize;
  final int fontWeight; // 100..900
  final bool italic;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final ReadAlign align;
  final bool rtl;
  final int textColor;
  final int backgroundColor;
  final bool mirrorHorizontal;
  final bool flipVertical;

  /// Fraction (0.3–1.0) of the viewport width used by the text column.
  final double readingWidth;
  final double horizontalMargin;

  /// Vertical position (0–1) of the reading line within the viewport.
  final double guidePosition;
  final bool showGuide;

  /// Reading pace: seconds spent on each line of text. Lower = faster.
  /// Independent of font size (pixel speed is derived from it).
  final double secondsPerLine;

  /// Scroll speed in logical pixels per second for the current typography.
  double get pixelsPerSecond => fontSize * lineHeight / secondsPerLine;

  /// One tap of the faster/slower buttons (finer steps at fast paces).
  static double nudgeSeconds(double current, {required bool faster}) {
    final step = current <= 2 ? 0.1 : (current <= 6 ? 0.5 : 1.0);
    final v = faster ? current - step : current + step;
    return (v.clamp(0.3, 15) * 10).round() / 10;
  }

  final int countdownSeconds;
  final bool autoHideControls;
  final ReadingMode mode;

  /// Paragraph mode: seconds to hold after each paragraph.
  final double paragraphPause;

  /// Continuous mode: pause for [autoPauseFor] s after every N seconds of
  /// scrolling (0 = off).
  final int autoPauseEvery;
  final int autoPauseFor;

  final bool pipPortrait;

  /// Enter system PiP automatically when leaving the app while playing.
  final bool autoPip;

  /// Font-size multiplier applied while inside the PiP window.
  final double pipFontScale;

  static const speedPresets = <String, double>{
    'Slow': 3.0,
    'Medium': 1.5,
    'Fast': 0.8,
    'Very fast': 0.5,
  };

  TeleprompterSettings copyWith({
    Object? fontFamily = _keep,
    double? fontSize,
    int? fontWeight,
    bool? italic,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    ReadAlign? align,
    bool? rtl,
    int? textColor,
    int? backgroundColor,
    bool? mirrorHorizontal,
    bool? flipVertical,
    double? readingWidth,
    double? horizontalMargin,
    double? guidePosition,
    bool? showGuide,
    double? secondsPerLine,
    int? countdownSeconds,
    bool? autoHideControls,
    ReadingMode? mode,
    double? paragraphPause,
    int? autoPauseEvery,
    int? autoPauseFor,
    bool? pipPortrait,
    bool? autoPip,
    double? pipFontScale,
  }) => TeleprompterSettings(
    fontFamily: identical(fontFamily, _keep)
        ? this.fontFamily
        : fontFamily as String?,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    italic: italic ?? this.italic,
    lineHeight: lineHeight ?? this.lineHeight,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    align: align ?? this.align,
    rtl: rtl ?? this.rtl,
    textColor: textColor ?? this.textColor,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    mirrorHorizontal: mirrorHorizontal ?? this.mirrorHorizontal,
    flipVertical: flipVertical ?? this.flipVertical,
    readingWidth: readingWidth ?? this.readingWidth,
    horizontalMargin: horizontalMargin ?? this.horizontalMargin,
    guidePosition: guidePosition ?? this.guidePosition,
    showGuide: showGuide ?? this.showGuide,
    secondsPerLine: secondsPerLine ?? this.secondsPerLine,
    countdownSeconds: countdownSeconds ?? this.countdownSeconds,
    autoHideControls: autoHideControls ?? this.autoHideControls,
    mode: mode ?? this.mode,
    paragraphPause: paragraphPause ?? this.paragraphPause,
    autoPauseEvery: autoPauseEvery ?? this.autoPauseEvery,
    autoPauseFor: autoPauseFor ?? this.autoPauseFor,
    pipPortrait: pipPortrait ?? this.pipPortrait,
    autoPip: autoPip ?? this.autoPip,
    pipFontScale: pipFontScale ?? this.pipFontScale,
  );

  Map<String, Object?> toJson() => {
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'fontWeight': fontWeight,
    'italic': italic,
    'lineHeight': lineHeight,
    'letterSpacing': letterSpacing,
    'paragraphSpacing': paragraphSpacing,
    'align': align.name,
    'rtl': rtl,
    'textColor': textColor,
    'backgroundColor': backgroundColor,
    'mirrorHorizontal': mirrorHorizontal,
    'flipVertical': flipVertical,
    'readingWidth': readingWidth,
    'horizontalMargin': horizontalMargin,
    'guidePosition': guidePosition,
    'showGuide': showGuide,
    'secondsPerLine': secondsPerLine,
    'countdownSeconds': countdownSeconds,
    'autoHideControls': autoHideControls,
    'mode': mode.name,
    'paragraphPause': paragraphPause,
    'autoPauseEvery': autoPauseEvery,
    'autoPauseFor': autoPauseFor,
    'pipPortrait': pipPortrait,
    'autoPip': autoPip,
    'pipFontScale': pipFontScale,
  };

  /// Tolerant of missing/invalid keys so older or hand-edited data never
  /// prevents the app from starting.
  factory TeleprompterSettings.fromJson(Map<String, Object?> j) {
    const d = TeleprompterSettings();
    double n(String k, double def, double lo, double hi) =>
        ((j[k] as num?)?.toDouble() ?? def).clamp(lo, hi).toDouble();
    return TeleprompterSettings(
      fontFamily: j['fontFamily'] as String?,
      fontSize: n('fontSize', d.fontSize, 12, 200),
      fontWeight: ((j['fontWeight'] as num?)?.toInt() ?? d.fontWeight).clamp(
        100,
        900,
      ),
      italic: j['italic'] as bool? ?? d.italic,
      lineHeight: n('lineHeight', d.lineHeight, 1, 3),
      letterSpacing: n('letterSpacing', d.letterSpacing, -2, 10),
      paragraphSpacing: n('paragraphSpacing', d.paragraphSpacing, 0, 120),
      align: ReadAlign.values.asNameMap()[j['align']] ?? d.align,
      rtl: j['rtl'] as bool? ?? d.rtl,
      textColor: (j['textColor'] as num?)?.toInt() ?? d.textColor,
      backgroundColor:
          (j['backgroundColor'] as num?)?.toInt() ?? d.backgroundColor,
      mirrorHorizontal: j['mirrorHorizontal'] as bool? ?? d.mirrorHorizontal,
      flipVertical: j['flipVertical'] as bool? ?? d.flipVertical,
      readingWidth: n('readingWidth', d.readingWidth, 0.3, 1),
      horizontalMargin: n('horizontalMargin', d.horizontalMargin, 0, 200),
      guidePosition: n('guidePosition', d.guidePosition, 0.05, 0.95),
      showGuide: j['showGuide'] as bool? ?? d.showGuide,
      secondsPerLine: n('secondsPerLine', d.secondsPerLine, 0.3, 15),
      countdownSeconds:
          ((j['countdownSeconds'] as num?)?.toInt() ?? d.countdownSeconds)
              .clamp(0, 30),
      autoHideControls: j['autoHideControls'] as bool? ?? d.autoHideControls,
      mode: ReadingMode.values.asNameMap()[j['mode']] ?? d.mode,
      paragraphPause: n('paragraphPause', d.paragraphPause, 0, 30),
      autoPauseEvery: ((j['autoPauseEvery'] as num?)?.toInt() ?? 0).clamp(
        0,
        600,
      ),
      autoPauseFor: ((j['autoPauseFor'] as num?)?.toInt() ?? d.autoPauseFor)
          .clamp(1, 120),
      pipPortrait: j['pipPortrait'] as bool? ?? d.pipPortrait,
      autoPip: j['autoPip'] as bool? ?? d.autoPip,
      pipFontScale: n('pipFontScale', d.pipFontScale, 0.3, 1.5),
    );
  }
}

const Object _keep = Object();
