import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teleprompter/features/teleprompter/playback_controller.dart';

class _Host extends StatefulWidget {
  const _Host({required this.onReady});
  final void Function(PlaybackController) onReady;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final pc = PlaybackController(
    vsync: this,
    speed: 100,
    countdownSeconds: 0,
  );
  @override
  void initState() {
    super.initState();
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
        children: [for (var i = 0; i < 100; i++) const SizedBox(height: 100)],
      ),
    ),
  );
}

void main() {
  testWidgets('scrolls at the configured speed, pauses, finishes', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(_Host(onReady: (c) => pc = c));

    pc.play();
    expect(pc.status, PlaybackStatus.playing);
    // Pump in 16ms frames for ~1s; dt is capped at 50ms per frame.
    for (var i = 0; i < 63; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(pc.scroll.offset, closeTo(100, 8));

    pc.pause();
    final at = pc.scroll.offset;
    await t.pump(const Duration(seconds: 1));
    expect(pc.scroll.offset, at);
    expect(pc.status, PlaybackStatus.paused);

    pc.seek(1);
    pc.play();
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(pc.status, PlaybackStatus.finished);
  });

  testWidgets('a stalled frame does not cause a jump', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(_Host(onReady: (c) => pc = c));
    pc.play();
    await t.pump(const Duration(milliseconds: 16));
    await t.pump(const Duration(seconds: 3)); // simulated hitch
    expect(pc.scroll.offset, lessThanOrEqualTo(6)); // 100px/s * 0.05s cap
  });

  testWidgets('countdown precedes playback; stop rewinds', (t) async {
    late PlaybackController pc;
    await t.pumpWidget(_Host(onReady: (c) => pc = c));
    pc.countdownSeconds = 2;
    pc.play();
    expect(pc.status, PlaybackStatus.countdown);
    for (var i = 0; i < 80; i++) {
      await t.pump(const Duration(milliseconds: 40));
    }
    expect(pc.status, PlaybackStatus.playing);
    pc.stop();
    expect(pc.scroll.offset, 0);
    expect(pc.status, PlaybackStatus.idle);
  });
}
