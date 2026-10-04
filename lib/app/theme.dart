import 'package:flutter/material.dart';

ThemeData buyerTheme() => ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  colorScheme:
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFE6007A),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFFB60060),
        secondary: const Color(0xFF4C1268),
        surface: const Color(0xFFFFFBFD),
        error: const Color(0xFFB42318),
      ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF211C23),
    centerTitle: false,
    scrolledUnderElevation: 1,
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
  ),
);
