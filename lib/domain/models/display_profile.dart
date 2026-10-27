import 'teleprompter_settings.dart';

/// A named snapshot of [TeleprompterSettings] (e.g. "Studio", "Phone selfie").
class DisplayProfile {
  const DisplayProfile(this.name, this.settings);
  final String name;
  final TeleprompterSettings settings;

  Map<String, Object?> toJson() => {
    'name': name,
    'settings': settings.toJson(),
  };

  factory DisplayProfile.fromJson(Map<String, Object?> j) => DisplayProfile(
    j['name'] as String? ?? 'Profile',
    TeleprompterSettings.fromJson(
      (j['settings'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
  );
}
