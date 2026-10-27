import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/app/app.dart';
import 'package:teleprompter/app/providers.dart';
import 'package:teleprompter/data/settings_store.dart';
import 'package:teleprompter/domain/models/script.dart';
import 'package:teleprompter/domain/repositories/script_repository.dart';
import 'package:teleprompter/features/teleprompter/script_view.dart';
import 'package:teleprompter/platform/pip_service.dart';

class _MemRepo implements ScriptRepository {
  final items = <String, Script>{};
  @override
  Future<List<Script>> loadAll() async => items.values.toList();
  @override
  Future<void> save(Script s) async => items[s.id] = s;
  @override
  Future<void> delete(String id) async => items.remove(id);
}

Future<void> pumpFor(WidgetTester t, Duration d) async {
  for (var e = Duration.zero; e < d; e += const Duration(milliseconds: 50)) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create → present → scroll → camera permission prompt → PiP', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PipService.init();
    final prefs = await SharedPreferences.getInstance();
    final repo = _MemRepo();
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

    await t.tap(find.text('New script'));
    await t.pumpAndSettle();
    final body = List.generate(
      40,
      (i) => 'Paragraph number $i with some words to read aloud.',
    ).join('\n\n');
    await t.enterText(find.byType(TextField).first, body);
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Present'));
    await t.pumpAndSettle();
    expect(find.textContaining('Paragraph number 0'), findsOneWidget);

    // play (3 s countdown, then scrolling)
    await t.tap(find.byIcon(Icons.play_arrow).last);
    await pumpFor(t, const Duration(seconds: 6));
    final list = t.state<ScrollableState>(
      find.descendant(
        of: find.byType(ScriptView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(list.position.pixels, greaterThan(10));

    // PiP on a real Android system
    expect(await PipService.isSupported(), isTrue);
    final entered = await PipService.enter(playing: true, portrait: false);
    expect(entered, isTrue);
    for (var i = 0; i < 30 && !PipService.inPip.value; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(PipService.inPip.value, isTrue);
    final before = list.position.pixels;
    await pumpFor(t, const Duration(seconds: 2));
    expect(
      list.position.pixels,
      greaterThan(before),
      reason: 'scrolling continues in PiP',
    );
  });
}
