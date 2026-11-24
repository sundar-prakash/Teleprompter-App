import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/log.dart';
import '../domain/models/teleprompter_settings.dart';

/// OS-level floating window above other apps (Android SYSTEM_ALERT_WINDOW +
/// foreground service). The overlay is its own Flutter engine/isolate
/// (see `overlayMain`), so data is passed as JSON messages.
///
/// Why messages only flow app → overlay here: in flutter_overlay_window 1.0.2
/// the overlay engine registers its own copy of the plugin, which overwrites
/// the shared messenger, so messages the overlay sends usually loop back into
/// the overlay instead of reaching the app. App → overlay is reliable, so the
/// app pushes the script (retrying until the window is up) and the overlay
/// reports its reading position through a small file instead.
class OverlayService {
  OverlayService._();

  /// Overlay window size in logical pixels (dp).
  static const baseWidth = 320;
  static const baseHeight = 240;

  /// Delays (from showing the overlay) at which the script is pushed again,
  /// in case the overlay window wasn't listening yet. The overlay ignores
  /// repeats of the same session.
  static const _pushSchedule = [0, 150, 400, 900, 1800, 3500];

  static StreamSubscription? _sub;
  static Map<String, Object?>? _initPayload;
  static final List<Timer> _pushTimers = [];
  static String? _progressPath;

  static void _listen() {
    // Kept for when the plugin's routing does deliver overlay messages.
    _sub ??= FlutterOverlayWindow.overlayListener.listen((m) {
      if (m is Map && m['t'] == 'ready') _push();
    });
  }

  static void _push() {
    final payload = _initPayload;
    if (payload == null) return;
    FlutterOverlayWindow.shareData(payload).catchError((Object e) {
      logError('overlay.push', e, StackTrace.current);
    });
  }

  static Future<String> _progressFile() async => _progressPath ??= p.join(
    (await getTemporaryDirectory()).path,
    'overlay_progress.json',
  );

  /// Reading position (0–1) the overlay reached for [scriptId] during the
  /// current session, or null. Clears it once read.
  static double? takeProgress(String scriptId) {
    final path = _progressPath;
    final session = _initPayload?['session'];
    if (path == null || session == null) return null;
    final f = File(path);
    try {
      if (!f.existsSync()) return null;
      final m = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      f.deleteSync();
      if (m['scriptId'] != scriptId || m['session'] != session) return null;
      return (m['v'] as num).toDouble().clamp(0.0, 1.0);
    } catch (e, st) {
      logError('overlay.progress', e, st);
      return null;
    }
  }

  static Future<bool> isActive() async {
    if (!Platform.isAndroid) return false;
    try {
      return await FlutterOverlayWindow.isActive();
    } catch (_) {
      return false;
    }
  }

  /// Caller must have ensured the overlay permission first.
  static Future<void> show({
    required String scriptId,
    required String text,
    required TeleprompterSettings settings,
    double progress = 0,
    double opacity = 0.85,
  }) async {
    final progressPath = await _progressFile();
    try {
      final f = File(progressPath);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}

    _initPayload = {
      't': 'init',
      'session': DateTime.now().microsecondsSinceEpoch,
      'scriptId': scriptId,
      'progressFile': progressPath,
      'text': text,
      'settings': settings.toJson(),
      'progress': progress,
      'opacity': opacity,
    };
    _listen();

    // The plugin applies the *initial* size in physical pixels (resizes use
    // dp), so convert here or the window opens tiny on high-density screens.
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    await FlutterOverlayWindow.showOverlay(
      width: (baseWidth * dpr).round(),
      height: (baseHeight * dpr).round(),
      alignment: OverlayAlignment.topCenter,
      enableDrag: true,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Teleprompter',
      overlayContent: 'Floating script is running',
      visibility: NotificationVisibility.visibilityPublic,
    );

    for (final t in _pushTimers) {
      t.cancel();
    }
    _pushTimers
      ..clear()
      ..addAll([
        for (final ms in _pushSchedule)
          Timer(Duration(milliseconds: ms), _push),
      ]);
  }

  static Future<void> close() async {
    for (final t in _pushTimers) {
      t.cancel();
    }
    _pushTimers.clear();
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e, st) {
      logError('overlay.close', e, st);
    }
  }
}
