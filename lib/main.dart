import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/log.dart';
import 'core/platform.dart';
import 'data/file_script_repository.dart';
import 'data/settings_store.dart';
import 'features/overlay/overlay_app.dart';
import 'platform/pip_service.dart';

/// Entry point of the floating overlay engine; the overlay plugin looks this
/// up by name in the main library.
@pragma('vm:entry-point')
void overlayMain() => runOverlayApp();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    logError('flutter', d.exception, d.stack);
  };

  PipService.init();
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(480, 400));
  }

  final prefs = await SharedPreferences.getInstance();
  final docs = await getApplicationDocumentsDirectory();
  final scriptsDir = Directory(p.join(docs.path, 'TeleprompterPro', 'scripts'));

  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
        scriptRepositoryProvider.overrideWithValue(
          FileScriptRepository(scriptsDir),
        ),
      ],
      child: const TeleprompterApp(),
    ),
  );
}
