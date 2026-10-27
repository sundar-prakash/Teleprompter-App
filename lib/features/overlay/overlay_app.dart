import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../domain/models/teleprompter_settings.dart';
import '../../platform/overlay_service.dart';
import '../teleprompter/playback_controller.dart';
import '../teleprompter/script_view.dart';

/// Body of the floating overlay engine (called from `overlayMain` in main.dart).
void runOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      color: Colors.transparent,
      home: const _OverlayScreen(),
    ),
  );
}

class _OverlayScreen extends StatefulWidget {
  const _OverlayScreen();
  @override
  State<_OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<_OverlayScreen>
    with SingleTickerProviderStateMixin {
  late final PlaybackController _pc = PlaybackController(
    vsync: this,
    speed: 80,
  );
  StreamSubscription? _sub;
  Timer? _reportTimer;
  Timer? _readyTimer;

  TeleprompterSettings? _s;
  List<String> _paragraphs = const [];
  double _opacity = 0.85;
  double _fontScale = 1;
  bool _locked = false;
  bool _minimized = false;
  int _sizeStep = 1;
  static const _sizes = [0.7, 1.0, 1.3, 1.6];

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen((m) {
      if (m is! Map || m['t'] != 'init') return;
      _readyTimer?.cancel();
      final s = TeleprompterSettings.fromJson(
        (m['settings'] as Map).cast<String, Object?>(),
      );
      setState(() {
        _s = s.copyWith(
          mode: s.mode == ReadingMode.subtitle
              ? ReadingMode.continuous
              : s.mode,
          fontSize: s.fontSize * 0.55,
        );
        _fontScale = 1;
        _opacity = (m['opacity'] as num).toDouble();
        _paragraphs = paragraphsFor(m['text'] as String);
      });
      _pc.configure(_scaled);
      final p = (m['progress'] as num).toDouble();
      if (p > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _pc.seek(p));
      }
    });
    _pc.addListener(() => setState(() {}));
    // Ask the main app for the script until it arrives.
    _readyTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      FlutterOverlayWindow.shareData({'t': 'ready'});
    });
    FlutterOverlayWindow.shareData({'t': 'ready'});
    _reportTimer = Timer.periodic(const Duration(seconds: 2), (_) => _report());
  }

  void _report() {
    if (_s == null) return;
    FlutterOverlayWindow.shareData({'t': 'progress', 'v': _pc.progress});
  }

  TeleprompterSettings get _scaled =>
      _s!.copyWith(fontSize: _s!.fontSize * _fontScale);

  void _resize() {
    final f = _sizes[_sizeStep];
    FlutterOverlayWindow.resizeOverlay(
      (OverlayService.baseWidth * f).round(),
      (OverlayService.baseHeight * f).round(),
      !_locked,
    );
  }

  void _setMinimized(bool v) {
    setState(() => _minimized = v);
    if (v) {
      FlutterOverlayWindow.resizeOverlay(56, 56, true);
    } else {
      _resize();
    }
  }

  void _tweakSpeed(double d) {
    _s = _s!.copyWith(
      secondsPerLine: TeleprompterSettings.nudgeSeconds(
        _s!.secondsPerLine,
        faster: d > 0,
      ),
    );
    _pc.configure(_scaled);
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    _readyTimer?.cancel();
    _sub?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) {
      return Material(
        color: Colors.transparent,
        child: Center(
          child: FloatingActionButton(
            heroTag: null,
            mini: false,
            onPressed: () => _setMinimized(false),
            child: Icon(_pc.isPlaying ? Icons.play_arrow : Icons.subject),
          ),
        ),
      );
    }
    if (_s == null) {
      return Material(
        color: Colors.black87,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 8),
            const Text(
              'Loading script…',
              style: TextStyle(color: Colors.white70),
            ),
            TextButton(
              onPressed: FlutterOverlayWindow.closeOverlay,
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
    const bar = Color(0xCC000000);
    Widget btn(IconData i, String tip, VoidCallback f, {bool on = false}) =>
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            tooltip: tip,
            color: on ? Theme.of(context).colorScheme.primary : Colors.white,
            icon: Icon(i),
            onPressed: f,
          ),
        );

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScriptView(
                      paragraphs: _paragraphs,
                      settings: _scaled,
                      playback: _pc,
                      backgroundOpacity: _opacity,
                    ),
                  ),
                  if (_pc.status == PlaybackStatus.countdown)
                    Center(
                      child: Text(
                        '${_pc.countdownRemaining}',
                        style: const TextStyle(
                          fontSize: 64,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: bar,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  btn(
                    _pc.isPlaying ? Icons.pause : Icons.play_arrow,
                    'Play/pause',
                    _pc.toggle,
                  ),
                  btn(Icons.replay, 'Restart', _pc.restart),
                  btn(Icons.directions_walk, 'Slower', () => _tweakSpeed(-10)),
                  btn(Icons.directions_run, 'Faster', () => _tweakSpeed(10)),
                  btn(Icons.text_decrease, 'Smaller text', () {
                    setState(
                      () => _fontScale = (_fontScale - 0.1).clamp(0.5, 2),
                    );
                    _pc.configure(_scaled);
                  }),
                  btn(Icons.text_increase, 'Larger text', () {
                    setState(
                      () => _fontScale = (_fontScale + 0.1).clamp(0.5, 2),
                    );
                    _pc.configure(_scaled);
                  }),
                  btn(
                    Icons.opacity,
                    'Less opaque',
                    () => setState(
                      () => _opacity = (_opacity - 0.1).clamp(0.2, 1),
                    ),
                  ),
                  btn(
                    Icons.lens_blur,
                    'More opaque',
                    () => setState(
                      () => _opacity = (_opacity + 0.1).clamp(0.2, 1),
                    ),
                  ),
                  btn(Icons.flip, 'Mirror', () {
                    _s = _s!.copyWith(mirrorHorizontal: !_s!.mirrorHorizontal);
                    setState(() {});
                  }, on: _s!.mirrorHorizontal),
                  btn(Icons.zoom_out_map, 'Resize', () {
                    _sizeStep = (_sizeStep + 1) % _sizes.length;
                    _resize();
                  }),
                  btn(
                    _locked ? Icons.lock : Icons.lock_open,
                    _locked ? 'Unlock position' : 'Lock position',
                    () {
                      setState(() => _locked = !_locked);
                      _resize();
                    },
                    on: _locked,
                  ),
                  btn(
                    Icons.visibility_off,
                    'Minimise',
                    () => _setMinimized(true),
                  ),
                  btn(Icons.close, 'Close', () async {
                    _report();
                    await FlutterOverlayWindow.closeOverlay();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
