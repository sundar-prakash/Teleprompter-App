import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../core/theme.dart';
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
      theme: buildTheme(Brightness.dark),
      color: Colors.transparent,
      home: const OverlayScreen(),
    ),
  );
}

/// The floating script window. [messages] defaults to the plugin's stream;
/// tests inject their own.
class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key, this.messages});
  final Stream<dynamic>? messages;

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    with SingleTickerProviderStateMixin {
  late final PlaybackController _pc = PlaybackController(
    vsync: this,
    speed: 80,
  );
  StreamSubscription? _sub;
  Timer? _reportTimer;
  Timer? _timeoutTimer;

  TeleprompterSettings? _s;
  List<String> _paragraphs = const [];
  Object? _session;
  String? _scriptId;
  String? _progressFile;
  double _opacity = 0.85;
  double _fontScale = 1;
  bool _locked = false;
  bool _minimized = false;
  bool _timedOut = false;
  int _sizeStep = 1;
  static const _sizes = [0.7, 1.0, 1.3, 1.6];

  @override
  void initState() {
    super.initState();
    _sub = (widget.messages ?? FlutterOverlayWindow.overlayListener).listen(
      _onMessage,
    );
    _pc.addListener(() {
      if (mounted) setState(() {});
    });
    // Harmless if it never arrives; the app pushes the script regardless.
    _send({'t': 'ready'});
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _s == null) setState(() => _timedOut = true);
    });
    _reportTimer = Timer.periodic(const Duration(seconds: 2), (_) => _report());
  }

  void _onMessage(dynamic m) {
    if (m is! Map || m['t'] != 'init') return;
    // The app sends the same session several times; apply it only once.
    if (m['session'] != null && m['session'] == _session) return;
    _timeoutTimer?.cancel();
    final s = TeleprompterSettings.fromJson(
      (m['settings'] as Map).cast<String, Object?>(),
    );
    setState(() {
      _session = m['session'];
      _scriptId = m['scriptId'] as String?;
      _progressFile = m['progressFile'] as String?;
      _timedOut = false;
      _minimized = false;
      _s = s.copyWith(
        mode: s.mode == ReadingMode.subtitle ? ReadingMode.continuous : s.mode,
        fontSize: s.fontSize * 0.55,
      );
      _fontScale = 1;
      _opacity = (m['opacity'] as num).toDouble();
      _paragraphs = paragraphsFor(m['text'] as String);
    });
    _pc
      ..pause()
      ..configure(_scaled);
    // Make sure the window has its intended size in dp (see OverlayService).
    _resize();
    final p = (m['progress'] as num).toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pc.seek(p));
  }

  Future<void> _send(Map<String, Object?> data) async {
    if (widget.messages != null) return; // under test
    try {
      await FlutterOverlayWindow.shareData(data);
    } catch (_) {}
  }

  /// Saves the reading position where the app can pick it up when it comes
  /// back to the foreground.
  void _report() {
    final path = _progressFile;
    if (_s == null || path == null) return;
    try {
      File(path).writeAsStringSync(
        jsonEncode({
          'session': _session,
          'scriptId': _scriptId,
          'v': _pc.progress,
        }),
      );
    } catch (_) {}
  }

  TeleprompterSettings get _scaled =>
      _s!.copyWith(fontSize: _s!.fontSize * _fontScale);

  void _resize() {
    if (widget.messages != null) return; // under test
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
      if (widget.messages == null) {
        FlutterOverlayWindow.resizeOverlay(56, 56, true);
      }
    } else {
      _resize();
    }
  }

  void _tweakSpeed({required bool faster}) {
    _s = _s!.copyWith(
      secondsPerLine: TeleprompterSettings.nudgeSeconds(
        _s!.secondsPerLine,
        faster: faster,
      ),
    );
    _pc.configure(_scaled);
  }

  void _scaleText(double d) {
    setState(() => _fontScale = (_fontScale + d).clamp(0.5, 2.0));
    _pc.configure(_scaled);
  }

  Future<void> _close() async {
    _pc.pause();
    _report();
    if (widget.messages == null) await FlutterOverlayWindow.closeOverlay();
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    _timeoutTimer?.cancel();
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
            tooltip: 'Show script',
            onPressed: () => _setMinimized(false),
            child: Icon(_pc.isPlaying ? Icons.play_arrow : Icons.subject),
          ),
        ),
      );
    }
    if (_s == null) return _loading();

    Widget btn(IconData i, String tip, VoidCallback f, {bool on = false}) =>
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          iconSize: 20,
          tooltip: tip,
          color: on ? Theme.of(context).colorScheme.primary : Colors.white,
          icon: Icon(i),
          onPressed: f,
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
                      child: FittedBox(
                        child: Text(
                          '${_pc.countdownRemaining}',
                          style: const TextStyle(
                            fontSize: 64,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // One fixed-height row, so the controls can never push the script
            // out of a small window: play and close stay put, the rest scrolls.
            Container(
              height: 40,
              color: const Color(0xCC000000),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  btn(
                    _pc.isPlaying ? Icons.pause : Icons.play_arrow,
                    _pc.isPlaying ? 'Pause' : 'Play',
                    _pc.toggle,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          btn(
                            Icons.directions_walk,
                            'Slower',
                            () => _tweakSpeed(faster: false),
                          ),
                          btn(
                            Icons.directions_run,
                            'Faster',
                            () => _tweakSpeed(faster: true),
                          ),
                          btn(
                            Icons.text_decrease,
                            'Smaller text',
                            () => _scaleText(-0.1),
                          ),
                          btn(
                            Icons.text_increase,
                            'Larger text',
                            () => _scaleText(0.1),
                          ),
                          btn(Icons.replay, 'Restart', _pc.restart),
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
                            setState(
                              () => _s = _s!.copyWith(
                                mirrorHorizontal: !_s!.mirrorHorizontal,
                              ),
                            );
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
                            Icons.picture_in_picture_alt,
                            'Minimise',
                            () => _setMinimized(true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  btn(Icons.close, 'Close', _close),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact enough for the smallest window size; scales down rather than
  /// overflowing.
  Widget _loading() => Material(
    color: Colors.black87,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_timedOut) ...[
                const Text(
                  'Couldn\'t load the script.',
                  style: TextStyle(color: Colors.white),
                ),
                const Text(
                  'Close this window and tap "Float" again.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ] else ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Loading script…',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
              TextButton(onPressed: _close, child: const Text('Close')),
            ],
          ),
        ),
      ),
    ),
  );
}
