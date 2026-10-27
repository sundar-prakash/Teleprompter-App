import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/providers.dart';
import '../../core/log.dart';
import '../../domain/models/camera_prefs.dart';
import '../../domain/models/teleprompter_settings.dart';
import '../../domain/services/text_stats.dart';
import '../../platform/permissions.dart';
import '../teleprompter/playback_controller.dart';
import '../teleprompter/script_view.dart';
import '../teleprompter/speed_controls.dart';
import 'camera_settings_sheet.dart';

enum _Rec { idle, countdown, recording, paused }

ResolutionPreset _preset(VideoQuality q) => switch (q) {
  VideoQuality.p480 => ResolutionPreset.medium,
  VideoQuality.p720 => ResolutionPreset.high,
  VideoQuality.p1080 => ResolutionPreset.veryHigh,
  VideoQuality.p2160 => ResolutionPreset.ultraHigh,
};

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, required this.scriptId});
  final String scriptId;
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final PlaybackController _pc;
  CameraController? _cam;
  List<CameraDescription> _cameras = const [];
  bool _permissionDenied = false;
  bool _initializing = true;
  // Guards against overlapping inits (a second one disposes the first and
  // leaves CameraX in a failed state) and against lifecycle events fired by
  // Android's own permission dialog.
  bool _initRunning = false;
  bool _awaitingPermission = false;
  String? _error;
  String? _notice;
  bool _torch = false;

  _Rec _rec = _Rec.idle;
  int _preCount = 0;
  final _recWatch = Stopwatch();
  Timer? _uiTimer;
  Timer? _countTimer;

  XFile? _recorded;
  VideoPlayerController? _player;
  bool _saved = false;

  // floating box geometry (fractions of the available area)
  Offset _boxPos = const Offset(0.05, 0.25);
  Size _boxSize = const Size(0.9, 0.3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = ref.read(settingsProvider);
    _pc = PlaybackController(
      vsync: this,
      speed: s.pixelsPerSecond,
      countdownSeconds: 0,
    )..addListener(_onScript);
    _configureScript(s);
    _boxPos = Offset(0.05, ref.read(cameraPrefsProvider).scriptOffset);
    _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && _rec != _Rec.idle) setState(() {});
    });
    try {
      WakelockPlus.enable();
    } catch (_) {}
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _configureScript(TeleprompterSettings s) {
    // Recording has its own countdown; the script starts together with it.
    var eff = s.copyWith(
      countdownSeconds: 0,
      fontSize: s.fontSize * ref.read(cameraPrefsProvider).fontScale,
    );
    if (eff.mode == ReadingMode.subtitle || eff.mode == ReadingMode.manual) {
      eff = eff.copyWith(
        mode: eff.mode == ReadingMode.manual
            ? ReadingMode.manual
            : ReadingMode.continuous,
      );
    }
    _pc.configure(eff);
  }

  void _onScript() {
    if (_pc.status == PlaybackStatus.finished &&
        _rec == _Rec.recording &&
        ref.read(cameraPrefsProvider).stopWithScript) {
      _stopRecording();
    }
  }

  // ---- camera lifecycle ---------------------------------------------------

  Future<void> _bootstrap() async {
    _awaitingPermission = true;
    final bool ok;
    try {
      ok = await ensurePermissions(
        context,
        permissions: [Permission.camera, Permission.microphone],
        title: 'Camera and microphone',
        reason:
            'Recording yourself needs the camera for video and the microphone for sound. '
            'Nothing is recorded until you press the record button.',
      );
    } finally {
      _awaitingPermission = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _permissionDenied = true;
        _initializing = false;
      });
      return;
    }
    setState(() => _permissionDenied = false);
    await _initCamera();
  }

  Future<void> _initCamera({bool isRetry = false}) async {
    if (_initRunning) return;
    _initRunning = true;
    setState(() {
      _initializing = true;
      _error = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('none', 'No camera found on this device.');
      }
      final prefs = ref.read(cameraPrefsProvider);
      final want = prefs.frontCamera
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final desc = _cameras.firstWhere(
        (c) => c.lensDirection == want,
        orElse: () => _cameras.first,
      );

      // Try the requested quality, then step down if the device rejects it.
      CameraController? ok;
      VideoQuality used = prefs.quality;
      for (final q in VideoQuality.values.reversed.where(
        (q) => q.rank <= prefs.quality.rank,
      )) {
        final c = CameraController(
          desc,
          _preset(q),
          enableAudio: true,
          fps: prefs.fps,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        try {
          await c.initialize();
          ok = c;
          used = q;
          break;
        } on CameraException catch (e) {
          logError('camera.init ${q.label}', e);
          await c.dispose();
        }
      }
      if (ok == null) {
        throw CameraException('init', 'The camera could not be started.');
      }
      if (!mounted) {
        await ok.dispose();
        return;
      }
      await _cam?.dispose();
      setState(() {
        _cam = ok;
        _torch = false;
        _notice = used != prefs.quality
            ? 'This device could not use ${prefs.quality.label}; using ${used.label}.'
            : null;
      });
    } on CameraException catch (e) {
      logError('camera.init', e);
      if (mounted) setState(() => _error = _friendly(e));
    } catch (e, st) {
      logError('camera.init', e, st);
      if (mounted) setState(() => _error = 'The camera could not be started.');
    } finally {
      _initRunning = false;
      if (mounted) setState(() => _initializing = false);
    }
    // Right after a permission grant CameraX can fail once; retry quietly.
    if (_error != null && !isRetry && mounted && !_permissionDenied) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted && _cam == null) await _initCamera(isRetry: true);
    }
  }

  String _friendly(CameraException e) => switch (e.code) {
    'CameraAccessDenied' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' =>
      'Camera access is blocked. Enable it in system settings.',
    'AudioAccessDenied' || 'AudioAccessDeniedWithoutPrompt' =>
      'Microphone access is blocked. Enable it in system settings.',
    _ => e.description ?? 'The camera could not be started.',
  };

  Future<void> _releaseCamera() async {
    final c = _cam;
    setState(() => _cam = null);
    await c?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_awaitingPermission || _initRunning) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Android stops the camera in the background. Keep what was recorded.
      if (_rec == _Rec.recording || _rec == _Rec.paused) await _stopRecording();
      _countTimer?.cancel();
      if (_rec == _Rec.countdown) _rec = _Rec.idle;
      _pc.pause();
      await _releaseCamera();
    } else if (state == AppLifecycleState.resumed &&
        _recorded == null &&
        _cam == null &&
        !_permissionDenied) {
      await _initCamera();
    }
  }

  // ---- recording ----------------------------------------------------------

  Future<void> _record() async {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized || _rec != _Rec.idle) return;
    _pc.stop();
    final n = ref.read(settingsProvider).countdownSeconds;
    if (n > 0) {
      setState(() {
        _rec = _Rec.countdown;
        _preCount = n;
      });
      _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        if (_preCount <= 1) {
          t.cancel();
          _beginRecording();
        } else {
          setState(() => _preCount--);
        }
      });
    } else {
      await _beginRecording();
    }
  }

  Future<void> _beginRecording() async {
    final cam = _cam;
    if (cam == null) return;
    try {
      await cam.startVideoRecording();
      _recWatch
        ..reset()
        ..start();
      // Start the script immediately after recording starts so they share t=0.
      _pc.play();
      if (mounted) setState(() => _rec = _Rec.recording);
    } on CameraException catch (e) {
      logError('startVideoRecording', e);
      if (mounted) {
        setState(() => _rec = _Rec.idle);
        _snack('Could not start recording: ${e.description ?? e.code}');
      }
    }
  }

  Future<void> _togglePauseRecording() async {
    final cam = _cam;
    if (cam == null) return;
    try {
      if (_rec == _Rec.recording) {
        await cam.pauseVideoRecording();
        _recWatch.stop();
        _pc.pause();
        setState(() => _rec = _Rec.paused);
      } else if (_rec == _Rec.paused) {
        await cam.resumeVideoRecording();
        _recWatch.start();
        _pc.play();
        setState(() => _rec = _Rec.recording);
      }
    } on CameraException catch (e) {
      _snack('Pause/resume isn\'t supported here: ${e.description ?? e.code}');
    }
  }

  Future<void> _stopRecording() async {
    final cam = _cam;
    if (_rec == _Rec.countdown) {
      _countTimer?.cancel();
      setState(() => _rec = _Rec.idle);
      return;
    }
    if (cam == null || !cam.value.isRecordingVideo) return;
    _pc.pause();
    _recWatch.stop();
    try {
      final f = await cam.stopVideoRecording();
      final player = VideoPlayerController.file(File(f.path));
      await player.initialize();
      await player.setLooping(true);
      if (!mounted) {
        await player.dispose();
        return;
      }
      setState(() {
        _recorded = f;
        _player = player;
        _saved = false;
        _rec = _Rec.idle;
      });
      player.play();
    } on CameraException catch (e) {
      logError('stopVideoRecording', e);
      if (mounted) {
        setState(() => _rec = _Rec.idle);
        _snack(
          'The recording could not be finished: ${e.description ?? e.code}',
        );
      }
    }
  }

  Future<void> _saveToGallery() async {
    final f = _recorded;
    if (f == null) return;
    try {
      await Gal.putVideo(f.path, album: 'Teleprompter');
      setState(() => _saved = true);
      _snack('Saved to your gallery (Movies/Teleprompter).');
    } on GalException catch (e) {
      logError('gal', e);
      _snack(
        e.type == GalExceptionType.accessDenied
            ? 'Gallery access was denied. Use Share to save it elsewhere.'
            : 'Could not save the video: ${e.type.message}',
      );
    }
  }

  Future<void> _discard() async {
    final f = _recorded;
    await _player?.dispose();
    _player = null;
    _recorded = null;
    try {
      if (f != null) await File(f.path).delete();
    } catch (_) {}
    if (mounted) setState(() {});
    if (_cam == null) await _initCamera();
    _pc.stop();
  }

  Future<bool> _confirmLeave() async {
    if (_recorded == null || _saved) return true;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard recording?'),
        content: const Text('This video has not been saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  // ---- misc ---------------------------------------------------------------

  Future<void> _switchCamera() async {
    if (_rec != _Rec.idle) return;
    ref
        .read(cameraPrefsProvider.notifier)
        .update((p) => p.copyWith(frontCamera: !p.frontCamera));
    await _releaseCamera();
    await _initCamera();
  }

  Future<void> _toggleTorch() async {
    final cam = _cam;
    if (cam == null) return;
    try {
      final next = !_torch;
      await cam.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _torch = next);
    } on CameraException {
      _snack('This camera has no torch.');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _adjustSpeed({required bool faster}) => ref
      .read(settingsProvider.notifier)
      .update(
        (s) => s.copyWith(
          secondsPerLine: TeleprompterSettings.nudgeSeconds(
            s.secondsPerLine,
            faster: faster,
          ),
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _countTimer?.cancel();
    _pc
      ..removeListener(_onScript)
      ..dispose();
    // Release native camera resources (also stops any recording in progress).
    final cam = _cam;
    final player = _player;
    unawaited(() async {
      try {
        if (cam != null && cam.value.isRecordingVideo) {
          await cam.stopVideoRecording();
        }
      } catch (_) {}
      await cam?.dispose();
      await player?.dispose();
    }());
    try {
      WakelockPlus.disable();
    } catch (_) {}
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final script = ref.watch(scriptByIdProvider(widget.scriptId));
    final s = ref.watch(settingsProvider);
    ref.listen(settingsProvider, (_, n) => _configureScript(n));
    ref.listen(
      cameraPrefsProvider,
      (_, _) => _configureScript(ref.read(settingsProvider)),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_rec == _Rec.recording || _rec == _Rec.paused) {
          _snack('Stop the recording first.');
          return;
        }
        if (await _confirmLeave() && context.mounted) {
          await _discardSilently();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: script == null
            ? const Center(
                child: Text(
                  'Script not found.',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : _recorded != null
            ? _review()
            : _permissionDenied
            ? _permissionView()
            : _live(script.body, s),
      ),
    );
  }

  Future<void> _discardSilently() async {
    if (_recorded != null && !_saved) {
      try {
        await File(_recorded!.path).delete();
      } catch (_) {}
    }
  }

  Widget _permissionView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off, size: 56, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'Camera and microphone access is needed to record.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _bootstrap,
            child: const Text('Allow access'),
          ),
          TextButton(
            onPressed: openAppSettings,
            child: const Text('Open app settings'),
          ),
          TextButton(onPressed: () => context.pop(), child: const Text('Back')),
        ],
      ),
    ),
  );

  Widget _preview() {
    final cam = _cam;
    if (_initializing && cam == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _initCamera,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }
    if (cam == null || !cam.value.isInitialized) return const SizedBox();
    final ps = cam.value.previewSize!;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: MediaQuery.orientationOf(context) == Orientation.portrait
              ? ps.height
              : ps.width,
          height: MediaQuery.orientationOf(context) == Orientation.portrait
              ? ps.width
              : ps.height,
          child: CameraPreview(cam),
        ),
      ),
    );
  }

  Widget _scriptWidget(
    String body,
    TeleprompterSettings s,
    CameraPrefs p, {
    double opacity = 1,
  }) {
    final eff = s.copyWith(fontSize: s.fontSize * p.fontScale);
    return ScriptView(
      paragraphs: paragraphsFor(body),
      settings: _pc.mode == ReadingMode.manual
          ? eff.copyWith(mode: ReadingMode.manual)
          : eff.copyWith(
              mode: eff.mode == ReadingMode.subtitle
                  ? ReadingMode.continuous
                  : eff.mode,
            ),
      playback: _pc,
      backgroundOpacity: opacity,
    );
  }

  Widget _live(String body, TeleprompterSettings s) {
    final p = ref.watch(cameraPrefsProvider);
    return SafeArea(
      top: p.layout != CameraLayout.underLens,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _layout(body, s, p)),
                if (_rec == _Rec.countdown)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: Text(
                          '$_preCount',
                          style: const TextStyle(
                            fontSize: 160,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(top: 8, left: 8, right: 8, child: _statusRow()),
                if (_notice != null)
                  Positioned(
                    top: 44,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _notice!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _controls(s, p),
        ],
      ),
    );
  }

  Widget _layout(String body, TeleprompterSettings s, CameraPrefs p) {
    final script = _scriptWidget(body, s, p, opacity: 1);
    final overlay = _scriptWidget(body, s, p, opacity: p.scriptOpacity);
    switch (p.layout) {
      case CameraLayout.scriptAbove:
        return Column(
          children: [
            Expanded(flex: (p.scriptHeight * 100).round(), child: script),
            Expanded(
              flex: ((1 - p.scriptHeight) * 100).round(),
              child: _preview(),
            ),
          ],
        );
      case CameraLayout.scriptBelow:
        return Column(
          children: [
            Expanded(
              flex: ((1 - p.scriptHeight) * 100).round(),
              child: _preview(),
            ),
            Expanded(flex: (p.scriptHeight * 100).round(), child: script),
          ],
        );
      case CameraLayout.transparentOverlay:
        return LayoutBuilder(
          builder: (_, c) => Stack(
            children: [
              Positioned.fill(child: _preview()),
              Positioned(
                left: 0,
                right: 0,
                top: c.maxHeight * p.scriptOffset,
                height: c.maxHeight * p.scriptHeight,
                child: overlay,
              ),
            ],
          ),
        );
      case CameraLayout.underLens:
        // Lens sits at the top edge on phones: keep a slim strip flush with it.
        return LayoutBuilder(
          builder: (_, c) => Stack(
            children: [
              Positioned.fill(child: _preview()),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: c.maxHeight * (p.scriptHeight * 0.55).clamp(0.12, 0.4),
                child: overlay,
              ),
            ],
          ),
        );
      case CameraLayout.split:
        return OrientationBuilder(
          builder: (_, o) {
            final kids = [Expanded(child: _preview()), Expanded(child: script)];
            return o == Orientation.landscape
                ? Row(children: kids)
                : Column(children: kids);
          },
        );
      case CameraLayout.floating:
        return LayoutBuilder(
          builder: (_, c) {
            final w = c.maxWidth, h = c.maxHeight;
            return Stack(
              children: [
                Positioned.fill(child: _preview()),
                Positioned(
                  left: _boxPos.dx * w,
                  top: _boxPos.dy * h,
                  width: _boxSize.width * w,
                  height: _boxSize.height * h,
                  child: Stack(
                    children: [
                      Positioned.fill(child: overlay),
                      // drag handle
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 28,
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(
                            () => _boxPos = Offset(
                              (_boxPos.dx + d.delta.dx / w).clamp(
                                0,
                                1 - _boxSize.width,
                              ),
                              (_boxPos.dy + d.delta.dy / h).clamp(
                                0,
                                1 - _boxSize.height,
                              ),
                            ),
                          ),
                          child: const ColoredBox(
                            color: Colors.black26,
                            child: Center(
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // resize handle
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onPanUpdate: (d) => setState(
                            () => _boxSize = Size(
                              (_boxSize.width + d.delta.dx / w).clamp(
                                0.3,
                                1 - _boxPos.dx,
                              ),
                              (_boxSize.height + d.delta.dy / h).clamp(
                                0.12,
                                1 - _boxPos.dy,
                              ),
                            ),
                          ),
                          child: const Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.open_in_full,
                              size: 18,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
    }
  }

  Widget _statusRow() {
    final rem = _pc.estimatedRemaining;
    final recording = _rec == _Rec.recording;
    return Row(
      children: [
        if (_rec == _Rec.recording || _rec == _Rec.paused)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color:
                        recording &&
                            (_recWatch.elapsedMilliseconds ~/ 500).isEven
                        ? Colors.red
                        : Colors.red.shade900,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _rec == _Rec.paused ? 'PAUSED ' : 'REC ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatDuration(_recWatch.elapsed),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        const Spacer(),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              'Script ${formatDuration(_pc.elapsed)}${rem == null ? '' : ' · −${formatDuration(rem)}'}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _controls(TeleprompterSettings s, CameraPrefs p) {
    final live = _rec == _Rec.recording || _rec == _Rec.paused;
    final canTorch = !p.frontCamera;
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Theme(
          data: ThemeData.dark(useMaterial3: true),
          child: ListenableBuilder(
            listenable: _pc,
            builder: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Restart script',
                      icon: const Icon(Icons.replay),
                      onPressed: _rec == _Rec.countdown ? null : _pc.restart,
                    ),
                    IconButton(
                      tooltip: _pc.isPlaying ? 'Pause script' : 'Play script',
                      icon: Icon(
                        _pc.isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 32,
                      ),
                      onPressed: _pc.canAutoPlay ? _pc.toggle : null,
                    ),
                    SpeedControls(
                      secondsPerLine: s.secondsPerLine,
                      onSlower: () => _adjustSpeed(faster: false),
                      onFaster: () => _adjustSpeed(faster: true),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Camera & layout settings',
                      icon: const Icon(Icons.tune),
                      onPressed: () => showCameraSettings(
                        context,
                        onChanged: live ? null : _initCamera,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Switch camera',
                      icon: const Icon(Icons.cameraswitch),
                      onPressed: live || (_cameras.length < 2 && _cam != null)
                          ? null
                          : _switchCamera,
                    ),
                    IconButton(
                      tooltip: 'Torch',
                      icon: Icon(
                        _torch ? Icons.flashlight_on : Icons.flashlight_off,
                      ),
                      onPressed: canTorch && _cam != null ? _toggleTorch : null,
                    ),
                    _RecordButton(
                      recording: live || _rec == _Rec.countdown,
                      onPressed: _cam == null
                          ? null
                          : (_rec == _Rec.idle ? _record : _stopRecording),
                    ),
                    IconButton(
                      tooltip: _rec == _Rec.paused
                          ? 'Resume recording'
                          : 'Pause recording',
                      icon: Icon(
                        _rec == _Rec.paused ? Icons.play_arrow : Icons.pause,
                      ),
                      onPressed: live ? _togglePauseRecording : null,
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: live
                          ? null
                          : () => Navigator.maybeOf(context)?.maybePop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _review() {
    final pl = _player!;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: pl.value.aspectRatio,
                child: GestureDetector(
                  onTap: () => pl.value.isPlaying ? pl.pause() : pl.play(),
                  child: VideoPlayer(pl),
                ),
              ),
            ),
          ),
          VideoProgressIndicator(
            pl,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: Icon(_saved ? Icons.check : Icons.save_alt),
                  label: Text(_saved ? 'Saved' : 'Save to gallery'),
                  onPressed: _saved ? null : _saveToGallery,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share / export'),
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(files: [XFile(_recorded!.path)]),
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: Text(_saved ? 'Record again' : 'Discard'),
                  onPressed: () async {
                    if (_saved || await _confirmLeave()) await _discard();
                  },
                ),
                TextButton(
                  onPressed: () async {
                    if (await _confirmLeave() && mounted) {
                      await _discardSilently();
                      if (mounted) context.pop();
                    }
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.recording, required this.onPressed});
  final bool recording;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: recording ? 'Stop recording' : 'Start recording',
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: onPressed == null ? Colors.grey : Colors.red,
            borderRadius: BorderRadius.circular(recording ? 8 : 30),
          ),
          margin: EdgeInsets.all(recording ? 14 : 0),
        ),
      ),
    ),
  );
}
