import 'package:flutter/material.dart';

/// Dark-only theme for Aegis Codex.
///
/// The app never renders light: [AppTheme.dark] is wired into both `theme`
/// and `darkTheme` with [ThemeMode.dark] forced, and the Android launch
/// themes are dark too — see `android/app/src/main/res` — so there is no
/// light flicker at startup.
abstract final class AppTheme {
  /// Near-black scaffold background (Dota's dark UI).
  static const scaffoldBackground = Color(0xFF101010);

  /// Card/sheet surface, slightly lighter than the scaffold.
  static const surface = Color(0xFF1C1C1E);

  /// Dota red — primary brand accent.
  static const primary = Color(0xFFC23C2A);

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(color: surface),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.25),
      ),
    );
  }
}
