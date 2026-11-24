// Renders every screen on small/typical/large phones, at normal and enlarged
// system font sizes, with the real Roboto font (tests otherwise use a
// placeholder font whose glyphs are full squares), and fails on any layout
// overflow.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/app/app.dart';
import 'package:teleprompter/app/providers.dart';
import 'package:teleprompter/core/theme.dart';
import 'package:teleprompter/data/importers/import_result.dart';
import 'package:teleprompter/data/settings_store.dart';
import 'package:teleprompter/domain/models/script.dart';
import 'package:teleprompter/domain/models/teleprompter_settings.dart';
import 'package:teleprompter/domain/repositories/script_repository.dart';
import 'package:teleprompter/domain/services/srt_parser.dart';
import 'package:teleprompter/features/overlay/overlay_app.dart';

class _MemRepo implements ScriptRepository {
  _MemRepo(List<Script> s) : items = {for (final x in s) x.id: x};
  final Map<String, Script> items;
  @override
  Future<List<Script>> loadAll() async => items.values.toList();
  @override
  Future<void> save(Script s) async => items[s.id] = s;
  @override
  Future<void> delete(String id) async => items.remove(id);
}

const _longTitle =
    'Quarterly all-hands keynote script for the product launch event';
final _body = List.generate(
  8,
  (i) =>
      'Paragraph ${i + 1}. Good morning everyone, and thank you for joining '
      'us today. Keep your eyes up and your pace steady.',
).join('\n\n');

Script _script(String id, String title) {
  final now = DateTime(2026, 11, 25);
  return Script(
    id: id,
    title: title,
    body: _body,
    createdAt: now,
    updatedAt: now,
    lastOpenedAt: now,
  );
}

Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String f) async =>
      ByteData.view((await File('$dir/$f').readAsBytes()).buffer);
  final roboto = FontLoader('Roboto');
  for (final f in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Italic.ttf',
  ]) {
    roboto.addFont(bytes(f));
  }
  await roboto.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(bytes('MaterialIcons-Regular.otf'))).load();
}

/// Collects overflow errors instead of failing on the first one.
class _Audit {
  final issues = <String>{};
  String step = '';
  late final FlutterExceptionHandler? _prev;

  void start() {
    _prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final text = d.toString();
      if (!text.contains('overflowed')) return _prev?.call(d);
      final by = RegExp(r'overflowed by ([\d.]+) pixels on the (\w+)')
          .firstMatch(text);
      final at = RegExp(r'lib/([\w/]+\.dart):(\d+)').firstMatch(text);
      issues.add(
        '$step → ${by?.group(1)}px ${by?.group(2)} '
        'at ${at?.group(1)}:${at?.group(2)}',
      );
    };
  }

  void stop() => FlutterError.onError = _prev;
}

const _phones = {
  'small 320x568': Size(320, 568),
  'typical 360x740': Size(360, 740),
  'large 412x915': Size(412, 915),
};
const _scales = [1.0, 1.3];

void main() {
  setUpAll(() async {
    await _loadRealFonts();
    PackageInfo.setMockInitialValues(
      appName: 'Teleprompter',
      packageName: 'in.sundarprakash.teleprompter',
      version: '1.0.2',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  for (final phone in _phones.entries) {
    for (final scale in _scales) {
      testWidgets('app screens fit: ${phone.key} @ text ${scale}x', (t) async {
        final audit = _Audit()..start();
        addTearDown(audit.stop);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        t.view.physicalSize = phone.value;
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);

        final repo = _MemRepo([
          _script('a', _longTitle),
          _script('b', 'Intro'),
          _script('c', 'Weekly vlog: what I learned building an app'),
        ]);
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
              scriptRepositoryProvider.overrideWithValue(repo),
            ],
            child: const TeleprompterApp(),
          ),
        );
        await t.pumpAndSettle();
        GoRouter router() =>
            GoRouter.of(t.element(find.byType(Scaffold).first));

        Future<void> scrollAll() async {
          for (var i = 0; i < 25; i++) {
            final s = find.byType(Scrollable);
            if (s.evaluate().isEmpty) return;
            await t.drag(s.first, const Offset(0, -300), warnIfMissed: false);
            await t.pump(const Duration(milliseconds: 50));
          }
        }

        audit.step = 'Home';
        await t.pumpAndSettle();

        audit.step = 'Library (list)';
        router().go('/library');
        await t.pumpAndSettle();
        audit.step = 'Library (grid)';
        final grid = find.byIcon(Icons.grid_view);
        if (grid.evaluate().isNotEmpty) {
          await t.tap(grid.first);
          await t.pumpAndSettle();
        }

        audit.step = 'Settings';
        router().go('/settings');
        await t.pumpAndSettle();
        await scrollAll();

        audit.step = 'About';
        router().push('/about');
        await t.pumpAndSettle();
        await scrollAll();

        audit.step = 'Editor';
        router().go('/editor/a');
        await t.pumpAndSettle();

        audit.step = 'Import preview (SRT)';
        router().go(
          '/import-preview',
          extra: const ImportResult(
            title: _longTitle,
            text: 'First line\n\nSecond line',
            format: SourceFormat.srt,
            fileName: 'quarterly-all-hands-keynote-final-v3.srt',
            cues: [
              SrtCue(1, Duration.zero, Duration(seconds: 2), 'First line'),
              SrtCue(
                2,
                Duration(seconds: 2),
                Duration(seconds: 4),
                'Second line',
              ),
            ],
            warnings: ['Some formatting could not be imported.'],
          ),
        );
        await t.pumpAndSettle();
        await scrollAll();

        audit.step = 'Prompter';
        router().go('/play/a');
        await t.pump(const Duration(milliseconds: 500));
        audit.step = 'Prompter (display & playback panel)';
        final tune = find.byIcon(Icons.tune);
        if (tune.evaluate().isNotEmpty) {
          await t.tap(tune.first);
          await t.pump(const Duration(milliseconds: 500));
          await scrollAll();
        }

        // Leave nothing animating between tests.
        await t.pumpWidget(const SizedBox());
        expect(audit.issues, isEmpty, reason: audit.issues.join('\n'));
      });
    }
  }

  // The floating window is tiny compared to a phone screen.
  const overlaySizes = {
    'small 224x168': Size(224, 168),
    'default 320x240': Size(320, 240),
    'largest 512x384': Size(512, 384),
  };
  for (final size in overlaySizes.entries) {
    for (final scale in _scales) {
      testWidgets('floating window fits: ${size.key} @ text ${scale}x', (
        t,
      ) async {
        final audit = _Audit()..start();
        addTearDown(audit.stop);
        t.view.physicalSize = size.value;
        t.view.devicePixelRatio = 1;
        t.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(t.view.reset);
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final messages = StreamController<dynamic>();
        addTearDown(messages.close);

        await t.pumpWidget(
          MaterialApp(
            theme: buildTheme(Brightness.dark),
            home: OverlayScreen(messages: messages.stream),
          ),
        );
        audit.step = 'Overlay loading';
        await t.pump();
        expect(find.text('Loading script…'), findsOneWidget);

        audit.step = 'Overlay timed out';
        await t.pump(const Duration(seconds: 7));
        expect(find.text('Couldn\'t load the script.'), findsOneWidget);

        audit.step = 'Overlay script';
        final init = {
          't': 'init',
          'session': 1,
          'scriptId': 'a',
          'text': _body,
          'settings': const TeleprompterSettings().toJson(),
          'progress': 0.0,
          'opacity': 0.85,
        };
        messages.add(init);
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text('Loading script…'), findsNothing);
        expect(find.byTooltip('Close'), findsOneWidget);
        expect(find.byTooltip('Play'), findsOneWidget);

        // A repeat of the same session must not reset anything.
        messages.add(init);
        await t.pump();

        await t.pumpWidget(const SizedBox());
        expect(audit.issues, isEmpty, reason: audit.issues.join('\n'));
      });
    }
  }
}
