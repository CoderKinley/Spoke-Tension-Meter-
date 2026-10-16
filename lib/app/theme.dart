import 'package:flutter/material.dart';

// Neutral instrument surfaces; blue indicates a reading, not verified safety.
const ink = Color(0xFF111419);
const panel = Color(0xFF1C222B);
const readingSurface = Color(0xFF243249);
const accent = Color(0xFF83B4FF);
const muted = Color(0xFFABB6C5);
const amber = Color(0xFFF2BD70);
const foreground = Color(0xFFEEF2F7);
const selectedSurface = Color(0xFF2B4364);

ThemeData labTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: panel,
        primary: accent,
      ).copyWith(
        onPrimary: const Color(0xFF102444),
        primaryContainer: selectedSurface,
        onPrimaryContainer: const Color(0xFFD8E7FF),
        secondary: const Color(0xFFB9C9DF),
        onSecondary: const Color(0xFF243247),
        secondaryContainer: const Color(0xFF303E52),
        onSecondaryContainer: const Color(0xFFE2EAF5),
        tertiary: amber,
        onTertiary: const Color(0xFF3F2B0D),
        tertiaryContainer: const Color(0xFF59401B),
        onTertiaryContainer: const Color(0xFFFFDEAE),
        onSurface: foreground,
        onSurfaceVariant: muted,
        surfaceDim: ink,
        surfaceBright: const Color(0xFF343C48),
        surfaceContainerLowest: const Color(0xFF0C0F13),
        surfaceContainerLow: const Color(0xFF171C23),
        surfaceContainer: panel,
        surfaceContainerHigh: const Color(0xFF262E3A),
        surfaceContainerHighest: const Color(0xFF303A48),
        outline: const Color(0xFF7D8A9C),
        outlineVariant: const Color(0xFF414D5E),
        surfaceTint: accent,
      ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ink,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: panel,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: ink,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: panel,
    indicatorColor: selectedSurface,
  ),
);
