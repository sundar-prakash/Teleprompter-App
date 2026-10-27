import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/log.dart';

/// Android system Picture-in-Picture (native `enterPictureInPictureMode`).
/// The same Flutter activity keeps running while in the PiP window, so script
/// scrolling continues; play/pause/speed are PiP remote actions.
/// No-op on other platforms.
class PipService {
  PipService._();
  static const _ch = MethodChannel('teleprompter/pip');

  static final inPip = ValueNotifier<bool>(false);
  static final _actions = StreamController<String>.broadcast();

  /// "play" | "pause" | "slower" | "faster"
  static Stream<String> get actions => _actions.stream;

  static void init() {
    if (!Platform.isAndroid) return;
    _ch.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pipChanged':
          inPip.value = call.arguments as bool;
        case 'pipAction':
          _actions.add(call.arguments as String);
      }
    });
  }

  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('isSupported') ?? false;
    } catch (e, st) {
      logError('pip.isSupported', e, st);
      return false;
    }
  }

  /// Keeps the PiP params (actions, auto-enter) in sync with playback state.
  static Future<void> configure({
    required bool autoEnter,
    required bool playing,
    required bool portrait,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('configure', {
        'autoEnter': autoEnter,
        'playing': playing,
        'portrait': portrait,
      });
    } catch (e, st) {
      logError('pip.configure', e, st);
    }
  }

  /// Sends the app to the background (like pressing Home).
  static Future<void> minimize() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('minimize');
    } catch (e, st) {
      logError('pip.minimize', e, st);
    }
  }

  static Future<bool> enter({
    required bool playing,
    required bool portrait,
  }) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('enter', {
            'playing': playing,
            'portrait': portrait,
          }) ??
          false;
    } catch (e, st) {
      logError('pip.enter', e, st);
      return false;
    }
  }
}
