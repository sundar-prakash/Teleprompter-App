import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/settings_store.dart';
import '../domain/models/camera_prefs.dart';
import '../domain/models/display_profile.dart';
import '../domain/models/script.dart';
import '../domain/models/teleprompter_settings.dart';
import '../domain/repositories/script_repository.dart';
import '../domain/services/srt_parser.dart';

/// Overridden in `main()` once async dependencies are ready.
final settingsStoreProvider = Provider<SettingsStore>(
  (_) => throw UnimplementedError(),
);
final scriptRepositoryProvider = Provider<ScriptRepository>(
  (_) => throw UnimplementedError(),
);

class SettingsNotifier extends Notifier<TeleprompterSettings> {
  @override
  TeleprompterSettings build() =>
      ref.read(settingsStoreProvider).loadSettings();

  void update(
    TeleprompterSettings Function(TeleprompterSettings) f, {
    bool persist = true,
  }) {
    state = f(state);
    if (persist) ref.read(settingsStoreProvider).saveSettings(state);
  }

  /// Writes the current state (used after a continuous gesture like pinch).
  void persist() => ref.read(settingsStoreProvider).saveSettings(state);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, TeleprompterSettings>(
      SettingsNotifier.new,
    );

class ProfilesNotifier extends Notifier<List<DisplayProfile>> {
  @override
  List<DisplayProfile> build() =>
      ref.read(settingsStoreProvider).loadProfiles();

  void _commit(List<DisplayProfile> p) {
    state = p;
    ref.read(settingsStoreProvider).saveProfiles(p);
  }

  /// Saves (or replaces by name) the current display settings as a profile.
  void saveCurrent(String name) => _commit([
    for (final p in state)
      if (p.name != name) p,
    DisplayProfile(name, ref.read(settingsProvider)),
  ]);

  void apply(DisplayProfile p) =>
      ref.read(settingsProvider.notifier).update((_) => p.settings);

  void remove(String name) => _commit([
    for (final p in state)
      if (p.name != name) p,
  ]);
}

final profilesProvider =
    NotifierProvider<ProfilesNotifier, List<DisplayProfile>>(
      ProfilesNotifier.new,
    );

class CameraPrefsNotifier extends Notifier<CameraPrefs> {
  @override
  CameraPrefs build() => ref.read(settingsStoreProvider).loadCameraPrefs();

  void update(CameraPrefs Function(CameraPrefs) f) {
    state = f(state);
    ref.read(settingsStoreProvider).saveCameraPrefs(state);
  }
}

final cameraPrefsProvider = NotifierProvider<CameraPrefsNotifier, CameraPrefs>(
  CameraPrefsNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ThemeMode.values.asNameMap()[ref.read(settingsStoreProvider).themeMode] ??
      ThemeMode.system;

  void set(ThemeMode m) {
    state = m;
    ref.read(settingsStoreProvider).setThemeMode(m.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class LibraryGridNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).libraryGrid;
  void set(bool v) {
    state = v;
    ref.read(settingsStoreProvider).setLibraryGrid(v);
  }
}

final libraryGridProvider = NotifierProvider<LibraryGridNotifier, bool>(
  LibraryGridNotifier.new,
);

class ScriptsNotifier extends AsyncNotifier<List<Script>> {
  ScriptRepository get _repo => ref.read(scriptRepositoryProvider);

  @override
  Future<List<Script>> build() => _repo.loadAll();

  List<Script> get _current => state.value ?? const [];

  Future<void> _put(Script s) async {
    await _repo.save(s);
    state = AsyncData([
      for (final x in _current)
        if (x.id != s.id) x,
      s,
    ]);
  }

  Future<Script> create({
    String title = 'Untitled script',
    String body = '',
    SourceFormat format = SourceFormat.manual,
    String? fileName,
    List<SrtCue> cues = const [],
  }) async {
    final now = DateTime.now();
    final imported = format != SourceFormat.manual;
    final s = Script(
      id: const Uuid().v4(),
      title: title,
      body: body,
      originalBody: imported ? body : null,
      sourceFormat: format,
      sourceFileName: fileName,
      cues: cues,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
    );
    await _put(s);
    return s;
  }

  Future<void> edit(String id, {String? title, String? body}) async {
    final s = _current.firstWhere((x) => x.id == id);
    await _put(s.copyWith(title: title, body: body, updatedAt: DateTime.now()));
  }

  Future<void> toggleBookmark(String id, int paragraph) async {
    final s = _current.firstWhere((x) => x.id == id);
    final b = {...s.bookmarks};
    b.contains(paragraph) ? b.remove(paragraph) : b.add(paragraph);
    await _put(s.copyWith(bookmarks: b.toList()..sort()));
  }

  Future<void> toggleHighlight(String id, int paragraph) async {
    final s = _current.firstWhere((x) => x.id == id);
    final h = {...s.highlights};
    h.contains(paragraph) ? h.remove(paragraph) : h.add(paragraph);
    await _put(s.copyWith(highlights: h.toList()..sort()));
  }

  Future<void> markOpened(String id) async {
    final s = _current.firstWhere((x) => x.id == id);
    await _put(s.copyWith(lastOpenedAt: DateTime.now()));
  }

  Future<void> duplicate(String id) async {
    final s = _current.firstWhere((x) => x.id == id);
    await create(title: '${s.title} (copy)', body: s.body);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData([
      for (final x in _current)
        if (x.id != id) x,
    ]);
  }
}

final scriptsProvider = AsyncNotifierProvider<ScriptsNotifier, List<Script>>(
  ScriptsNotifier.new,
);

final scriptByIdProvider = Provider.family<Script?, String>((ref, id) {
  final list = ref.watch(scriptsProvider).value ?? const [];
  for (final s in list) {
    if (s.id == id) return s;
  }
  return null;
});
