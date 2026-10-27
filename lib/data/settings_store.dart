import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/log.dart';
import '../domain/models/camera_prefs.dart';
import '../domain/models/display_profile.dart';
import '../domain/models/teleprompter_settings.dart';

class SettingsStore {
  SettingsStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kSettings = 'teleprompter_settings_v1';
  static const _kThemeMode = 'app_theme_mode';
  static const _kViewGrid = 'library_grid';

  TeleprompterSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const TeleprompterSettings();
    try {
      return TeleprompterSettings.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (e, st) {
      logError('loadSettings', e, st);
      return const TeleprompterSettings();
    }
  }

  Future<void> saveSettings(TeleprompterSettings s) =>
      _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  static const _kProfiles = 'display_profiles_v1';
  static const _kCamera = 'camera_prefs_v1';

  List<DisplayProfile> loadProfiles() {
    final raw = _prefs.getString(_kProfiles);
    if (raw == null) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          DisplayProfile.fromJson((j as Map).cast<String, Object?>()),
      ];
    } catch (e, st) {
      logError('loadProfiles', e, st);
      return const [];
    }
  }

  Future<void> saveProfiles(List<DisplayProfile> p) =>
      _prefs.setString(_kProfiles, jsonEncode([for (final x in p) x.toJson()]));

  CameraPrefs loadCameraPrefs() {
    final raw = _prefs.getString(_kCamera);
    if (raw == null) return const CameraPrefs();
    try {
      return CameraPrefs.fromJson(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (e, st) {
      logError('loadCameraPrefs', e, st);
      return const CameraPrefs();
    }
  }

  Future<void> saveCameraPrefs(CameraPrefs c) =>
      _prefs.setString(_kCamera, jsonEncode(c.toJson()));

  String? get themeMode => _prefs.getString(_kThemeMode);
  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  bool get libraryGrid => _prefs.getBool(_kViewGrid) ?? false;
  Future<void> setLibraryGrid(bool v) => _prefs.setBool(_kViewGrid, v);
}
