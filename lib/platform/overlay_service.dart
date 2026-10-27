import 'dart:async';
import 'dart:io';

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../core/log.dart';
import '../domain/models/teleprompter_settings.dart';

/// OS-level floating window above other apps (Android SYSTEM_ALERT_WINDOW +
/// foreground service). The overlay is its own Flutter engine/isolate
/// (see `overlayMain`), so data is passed as JSON messages.
class OverlayService {
  OverlayService._();

  static const baseWidth = 320;
  static const baseHeight = 240;

  /// Last script progress (0–1) reported by the overlay, by script id.
  static final Map<String, double> _progress = {};
  static StreamSubscription? _sub;
  static String? _activeScript;
  static Map<String, Object?>? _initPayload;

  /// The overlay runs in its own engine and announces `ready` once it can
  /// receive data; we answer with the script (no timing guesses).
  static void _listen() {
    _sub ??= FlutterOverlayWindow.overlayListener.listen((m) {
      if (m is! Map) return;
      switch (m['t']) {
        case 'ready':
          final p = _initPayload;
          if (p != null) FlutterOverlayWindow.shareData(p);
        case 'progress' when _activeScript != null:
          _progress[_activeScript!] = (m['v'] as num).toDouble();
      }
    });
  }

  /// Returns (and clears) progress made in the overlay since last asked.
  static double? takeProgress(String scriptId) => _progress.remove(scriptId);

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
    _activeScript = scriptId;
    _initPayload = {
      't': 'init',
      'text': text,
      'settings': settings.toJson(),
      'progress': progress,
      'opacity': opacity,
    };
    _listen();
    await FlutterOverlayWindow.showOverlay(
      width: baseWidth,
      height: baseHeight,
      alignment: OverlayAlignment.topCenter,
      enableDrag: true,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'Teleprompter',
      overlayContent: 'Floating script is running',
      visibility: NotificationVisibility.visibilityPublic,
    );
  }

  static Future<void> close() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e, st) {
      logError('overlay.close', e, st);
    }
  }
}
