import 'package:flutter/material.dart';

/// Brand violet from the logo gradient (cyan → blue → violet).
const brandSeed = Color(0xFF7A5CFF);

/// `fidelity` keeps the primary close to the vivid logo violet instead of a
/// muted lavender.
ColorScheme brandScheme(Brightness b) => ColorScheme.fromSeed(
  seedColor: brandSeed,
  brightness: b,
  dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
);

ThemeData buildTheme(Brightness b) {
  final scheme = brandScheme(b);
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
