import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teleprompter/app/app.dart';
import 'package:teleprompter/app/providers.dart';
import 'package:teleprompter/data/settings_store.dart';
import 'package:teleprompter/domain/models/script.dart';
import 'package:teleprompter/domain/repositories/script_repository.dart';

class _MemRepo implements ScriptRepository {
  final items = <String, Script>{};
  @override
  Future<List<Script>> loadAll() async => items.values.toList();
  @override
  Future<void> save(Script s) async => items[s.id] = s;
  @override
  Future<void> delete(String id) async => items.remove(id);
}

Future<void> _pumpApp(WidgetTester t, Size size, _MemRepo repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
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
}

void main() {
  testWidgets(
    'compact layout uses a bottom bar; create, edit, open workspace',
    (t) async {
      final repo = _MemRepo();
      await _pumpApp(t, const Size(400, 800), repo);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);

      await t.tap(find.text('New script'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byType(TextField).first,
        'First paragraph.\n\nSecond paragraph.',
      );
      await t.pump(const Duration(seconds: 1));
      expect(repo.items.values.single.body, contains('Second paragraph.'));

      await t.tap(find.text('Present'));
      await t.pumpAndSettle();
      expect(find.text('First paragraph.'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsWidgets);
    },
  );

  testWidgets('wide layout uses a navigation rail', (t) async {
    await _pumpApp(t, const Size(1400, 900), _MemRepo());
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
