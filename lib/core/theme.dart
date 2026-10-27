import 'package:flutter/material.dart';

const _accent = Color(0xFF4F8F7B);

ThemeData buildTheme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: _accent, brightness: b);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}
