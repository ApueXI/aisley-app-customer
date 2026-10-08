import 'package:flutter/material.dart';

const buyerPink = Color(0xFFB60060);
const buyerPurple = Color(0xFF4C1268);
const buyerBorder = Color(0xFFE4DFE3);

ThemeData buyerTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFE6007A),
          brightness: Brightness.light,
        ).copyWith(
          primary: buyerPink,
          secondary: buyerPurple,
          surface: Colors.white,
          onSurface: const Color(0xFF211C23),
          onSurfaceVariant: const Color(0xFF625A61),
          outlineVariant: buyerBorder,
          error: const Color(0xFFB42318),
        ),
    scaffoldBackgroundColor: const Color(0xFFF8F7F8),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF211C23),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: buyerBorder)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: const BorderSide(color: buyerBorder)),
    ),
    dividerTheme: const DividerThemeData(color: buyerBorder, space: 24),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8B8188)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: shape,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: shape,
      side: const BorderSide(color: buyerBorder),
      selectedColor: const Color(0xFFFCE8F2),
      labelStyle: const TextStyle(color: buyerPurple),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFFCE8F2),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: buyerPink,
      unselectedLabelColor: Color(0xFF625A61),
      indicatorColor: buyerPink,
      dividerColor: buyerBorder,
    ),
  );
}
