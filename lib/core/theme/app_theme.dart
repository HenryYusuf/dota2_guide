import 'package:flutter/material.dart';

/// Dark-only theme for Aegis Codex — an authentic, modern Dota 2 dark fantasy
/// & esports companion design system.
///
/// The app never renders light: [AppTheme.dark] is wired into both `theme`
/// and `darkTheme` with [ThemeMode.dark] forced, and the Android launch
/// themes are dark too — see `android/app/src/main/res` — so there is no
/// light flicker at startup.
abstract final class AppTheme {
  // --- Background & Surface Palette (Obsidian & Deep Slate) ---
  /// Deep obsidian slate scaffold background.
  static const scaffoldBackground = Color(0xFF0C0F17);

  /// Elevated card/sheet surface, layered slightly lighter than scaffold.
  static const surface = Color(0xFF141A24);

  /// Higher elevation surface for interactive cards, chips, and modals.
  static const surfaceElevated = Color(0xFF1B2332);

  /// Subtle highlight surface for hover, active, or focused states.
  static const surfaceHighlight = Color(0xFF263248);

  // --- Brand Accents (Dota Crimson & Mythic Gold) ---
  /// Dota crimson red — primary brand accent.
  static const primary = Color(0xFFE53935);

  /// Subtle glow / overlay of the primary accent.
  static const primaryGlow = Color(0x33E53935);

  /// Aegis / Shop gold accent.
  static const gold = Color(0xFFF59E0B);

  /// Lighter gold for badges and highlights.
  static const goldLight = Color(0xFFFBBF24);

  // --- Faction & Attribute Accents ---
  /// Radiant faction cyan / blue.
  static const radiant = Color(0xFF38BDF8);

  /// Dire faction crimson / rose.
  static const dire = Color(0xFFF43F5E);

  /// Strength attribute ruby red.
  static const strength = Color(0xFFEF4444);

  /// Agility attribute emerald green.
  static const agility = Color(0xFF10B981);

  /// Intelligence attribute celestial cyan.
  static const intelligence = Color(0xFF0EA5E9);

  /// Universal attribute amethyst purple.
  static const universal = Color(0xFFA855F7);

  // --- Neutral Tier Accents ---
  static const tier1 = Color(0xFF94A3B8); // Slate / Silver
  static const tier2 = Color(0xFF34D399); // Aquamarine Green
  static const tier3 = Color(0xFF60A5FA); // Royal Blue
  static const tier4 = Color(0xFFC084FC); // Purple / Violet
  static const tier5 = Color(0xFFFBBF24); // Mythic Amber / Gold

  // --- Borders & Dividers ---
  /// Default subtle border color for cards and containers.
  static const border = Color(0xFF222B3B);

  /// Lighter border for interactive or focused components.
  static const borderLight = Color(0xFF334155);

  // --- Text Colors ---
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  /// Builds the complete dark [ThemeData].
  static ThemeData dark() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          surface: surface,
          onSurface: textPrimary,
          surfaceContainerLowest: scaffoldBackground,
          surfaceContainerLow: surface,
          surfaceContainer: surfaceElevated,
          surfaceContainerHigh: surfaceHighlight,
          outline: border,
          outlineVariant: borderLight,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 4,
        height: 68,
        indicatorColor: primary.withValues(alpha: 0.22),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.3,
            );
          }
          return const TextStyle(
            color: textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceElevated,
        selectedColor: primary.withValues(alpha: 0.25),
        disabledColor: surface,
        secondarySelectedColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
