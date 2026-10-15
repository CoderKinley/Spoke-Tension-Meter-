import 'package:flutter/material.dart';

const ink = Color(0xFF101B1D);
const panel = Color(0xFF19282B);
const mint = Color(0xFF9BE9C9);
const muted = Color(0xFF9CACAE);
const amber = Color(0xFFF2C986);

ThemeData labTheme() => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  colorScheme: ColorScheme.fromSeed(
    seedColor: mint,
    brightness: Brightness.dark,
    surface: panel,
    primary: mint,
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
    indicatorColor: Color(0xFF35534B),
  ),
);
