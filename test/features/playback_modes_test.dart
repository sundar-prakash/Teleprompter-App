import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/domain/models/teleprompter_settings.dart';
import 'package:teleprompter/domain/services/srt_parser.dart';
import 'package:teleprompter/features/teleprompter/playback_controller.dart';

class _Host extends StatefulWidget {
  const _Host({
    required this.settings,
    this.cues = const [],
    required this.onReady,
  });
  final TeleprompterSettings settings;
  final List<SrtCue> cues;
  final void Function(PlaybackController) onReady;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final pc = PlaybackController(vsync: this, speed: 100);
  @override
  void initState() {
    super.initState();
    // 10 paragraphs of 200px at 0, 200, 400 ...
    pc.attachLayout('k', 50, () => [for (var i = 0; i < 10; i++) i * 200.0]);
    pc.configure(widget.settings, cues: widget.cues);
    widget.onReady(pc);
  }

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: SizedBox(
      height: 500,
      child: ListView(
        controller: pc.scroll,
        children: [for (var i = 0; i < 20; i++) const SizedBox(height: 100)],
      ),
    ),
  );
}

Future<void> run(WidgetTester t, int ms, {int step = 16}) async {
  for (var e = 0; e < ms; e += step) {
    await t.pump(Duration(milliseconds: step));
  }
}

void main() {
  // 44px * 1.5 line height / 0.66 s = 100 px/s
  const base = TeleprompterSettings(countdownSeconds: 0, secondsPerLine: 0.66);

  testWidgets('paragraph mode holds after each paragraph', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(
      _Host(
        settings: base.copyWith(mode: ReadingMode.paragraph, paragraphPause: 1),
        onReady: (c) => pc = c,
      ),
    );
    pc.play();
    await run(
      t,
      2100,
    ); // 200px takes ~2s -> arrives at paragraph 1 and starts holding
    expect(pc.scroll.offset, closeTo(200, 6));
    expect(pc.isHolding, isTrue);
    final held = pc.scroll.offset;
    await run(t, 500);
    expect(pc.scroll.offset, held); // still holding
    await run(t, 3000); // hold ends (1s) and moves toward paragraph 2 (400)
    expect(pc.scroll.offset, greaterThan(held));
    expect(pc.currentParagraph, anyOf(1, 2));
  });

  testWidgets('single line mode moves in whole-line steps', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(
      _Host(
        settings: base.copyWith(mode: ReadingMode.singleLine),
        onReady: (c) => pc = c,
      ),
    );
    pc.play();
    await run(t, 2000);
    // lineStep=50 -> after settling the offset is a multiple of 50.
    await run(t, 300);
    final rem = pc.scroll.offset % 50;
    expect(rem < 3 || rem > 47 || pc.isPlaying, isTrue);
    expect(pc.scroll.offset, greaterThanOrEqualTo(50));
    pc.jump(1, 0);
    pc.jump(-1, 0);
  });

  testWidgets('auto pause holds then resumes', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(
      _Host(
        settings: base.copyWith(autoPauseEvery: 1, autoPauseFor: 2),
        onReady: (c) => pc = c,
      ),
    );
    pc.play();
    await run(t, 1200);
    expect(pc.isHolding, isTrue);
    final at = pc.scroll.offset;
    await run(t, 1000);
    expect(pc.scroll.offset, at);
    await run(t, 2000);
    expect(pc.scroll.offset, greaterThan(at));
  });

  testWidgets('manual mode never auto-plays', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(
      _Host(
        settings: base.copyWith(mode: ReadingMode.manual),
        onReady: (c) => pc = c,
      ),
    );
    pc.play();
    expect(pc.isPlaying, isFalse);
    pc.jump(1, 120);
    expect(pc.scroll.offset, 120);
  });

  testWidgets('subtitle mode follows the wall clock and finishes', (t) async {
    late PlaybackController pc;
    final cues = [
      const SrtCue(1, Duration(seconds: 1), Duration(seconds: 2), 'A'),
      const SrtCue(2, Duration(seconds: 3), Duration(seconds: 4), 'B'),
    ];
    await t.pumpWidget(
      _Host(
        settings: base.copyWith(mode: ReadingMode.subtitle),
        cues: cues,
        onReady: (c) => pc = c,
      ),
    );
    pc.play();
    expect(pc.currentCue, isNull);
    await run(t, 1500);
    expect(pc.currentCue?.text, 'A');
    await run(t, 1700);
    expect(pc.currentCue?.text, 'B');
    await run(t, 1500);
    expect(pc.status, PlaybackStatus.finished);
    pc.seek(0.3);
    expect(pc.progress, closeTo(0.3, 0.01));
  });
}
