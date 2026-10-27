import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/teleprompter_settings.dart';
import '../../domain/services/srt_parser.dart';
import '../../domain/services/text_stats.dart';
import 'playback_controller.dart';

TextStyle scriptTextStyle(TeleprompterSettings s) => TextStyle(
  fontFamily: s.fontFamily,
  fontSize: s.fontSize,
  fontWeight: FontWeight.values[(s.fontWeight ~/ 100 - 1).clamp(0, 8)],
  fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
  height: s.lineHeight,
  letterSpacing: s.letterSpacing,
  color: Color(s.textColor),
);

/// Forces an exact line pitch so line stepping and paragraph offsets are exact.
StrutStyle scriptStrut(TeleprompterSettings s) => StrutStyle(
  fontFamily: s.fontFamily,
  fontSize: s.fontSize,
  height: s.lineHeight,
  forceStrutHeight: true,
);

TextAlign _align(ReadAlign a) => switch (a) {
  ReadAlign.left => TextAlign.left,
  ReadAlign.center => TextAlign.center,
  ReadAlign.right => TextAlign.right,
  ReadAlign.justify => TextAlign.justify,
};

Widget applyMirror(TeleprompterSettings s, Widget child) =>
    (s.mirrorHorizontal || s.flipVertical)
    ? Transform.scale(
        scaleX: s.mirrorHorizontal ? -1 : 1,
        scaleY: s.flipVertical ? -1 : 1,
        child: child,
      )
    : child;

/// Lazily-built, scroll-controller-driven script text with reading guide.
/// Paragraphs are separate list items so large scripts only lay out what is
/// on screen. Paragraph offsets for paragraph mode/bookmarks are computed
/// lazily on demand through [PlaybackController.attachLayout].
class ScriptView extends StatelessWidget {
  const ScriptView({
    super.key,
    required this.paragraphs,
    required this.settings,
    required this.playback,
    this.highlights = const {},
    this.bookmarks = const {},
    this.onParagraphLongPress,
    this.backgroundOpacity = 1,
  });

  final List<String> paragraphs;
  final TeleprompterSettings settings;
  final PlaybackController playback;
  final Set<int> highlights;
  final Set<int> bookmarks;
  final ValueChanged<int>? onParagraphLongPress;
  final double backgroundOpacity;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final style = scriptTextStyle(s);
    final strut = scriptStrut(s);
    final linePx = s.fontSize * s.lineHeight;
    // Single-line mode keeps every line on one exact grid: no paragraph gaps.
    final spacing = s.mode == ReadingMode.singleLine ? 0.0 : s.paragraphSpacing;
    final dir = s.rtl ? TextDirection.rtl : TextDirection.ltr;

    return ColoredBox(
      color: Color(s.backgroundColor).withValues(alpha: backgroundOpacity),
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight;
          final colW = math.min(
            c.maxWidth - 2 * s.horizontalMargin,
            c.maxWidth * s.readingWidth,
          );

          final key =
              '${Object.hashAll(paragraphs)}|${s.fontFamily}|${s.fontSize}|${s.fontWeight}|'
              '${s.italic}|${s.lineHeight}|${s.letterSpacing}|$spacing|${s.align}|${s.rtl}|$colW';
          playback.attachLayout(key, linePx, () {
            final out = <double>[];
            var y = 0.0;
            for (final p in paragraphs) {
              out.add(y);
              final tp = TextPainter(
                text: TextSpan(text: p, style: style),
                strutStyle: strut,
                textAlign: _align(s.align),
                textDirection: dir,
              )..layout(maxWidth: math.max(colW, 1));
              y += tp.height + spacing;
              tp.dispose();
            }
            return out;
          });

          final guideColor = Color(s.textColor);
          Widget view = Stack(
            children: [
              ListView.builder(
                controller: playback.scroll,
                padding: EdgeInsets.only(
                  top: h * s.guidePosition,
                  bottom: h * (1 - s.guidePosition),
                  left: s.horizontalMargin,
                  right: s.horizontalMargin,
                ),
                itemCount: paragraphs.length,
                itemBuilder: (_, i) {
                  Widget t = Text(
                    paragraphs[i],
                    style: style,
                    strutStyle: strut,
                    textAlign: _align(s.align),
                    textDirection: s.rtl ? TextDirection.rtl : null,
                  );
                  if (highlights.contains(i)) {
                    t = DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: t,
                    );
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: c.maxWidth * s.readingWidth,
                      ),
                      child: GestureDetector(
                        onLongPress: onParagraphLongPress == null
                            ? null
                            : () => onParagraphLongPress!(i),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: spacing),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SizedBox(width: double.infinity, child: t),
                              if (bookmarks.contains(i))
                                Positioned(
                                  left: -s.horizontalMargin.clamp(14, 40) + 2,
                                  top: 4,
                                  child: Icon(
                                    Icons.bookmark,
                                    size: 18,
                                    color: guideColor.withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (s.mode == ReadingMode.singleLine) ...[
                // Show exactly one line: mask everything above and below it.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: h * s.guidePosition,
                  child: IgnorePointer(
                    child: ColoredBox(color: Color(s.backgroundColor)),
                  ),
                ),
                Positioned(
                  top: h * s.guidePosition + linePx,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: ColoredBox(color: Color(s.backgroundColor)),
                  ),
                ),
              ] else if (s.showGuide)
                Positioned(
                  top: h * s.guidePosition - 1,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 2,
                      color: guideColor.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          );
          return applyMirror(s, view);
        },
      ),
    );
  }
}

/// Subtitle mode: shows the cue active at the playback clock.
class SubtitleView extends StatelessWidget {
  const SubtitleView({super.key, required this.cue, required this.settings});
  final SrtCue? cue;
  final TeleprompterSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    return ColoredBox(
      color: Color(s.backgroundColor),
      child: applyMirror(
        s,
        Align(
          alignment: Alignment(0, (s.guidePosition - 0.5) * 2),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: s.horizontalMargin + 8),
            child: Text(
              cue?.text ?? '',
              textAlign: _align(
                s.align == ReadAlign.justify ? ReadAlign.center : s.align,
              ),
              textDirection: s.rtl ? TextDirection.rtl : null,
              style: scriptTextStyle(s),
              strutStyle: scriptStrut(s),
            ),
          ),
        ),
      ),
    );
  }
}

List<String> paragraphsFor(String body) {
  final p = splitParagraphs(body);
  return p.isEmpty ? const ['(This script is empty.)'] : p;
}
