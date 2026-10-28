import 'package:flutter/material.dart';

const buyerPink = Color(0xFFB60060);
const buyerPurple = Color(0xFF4C1268);
const buyerBorder = Color(0xFFE4DFE3);
const buyerCanvas = Color(0xFFF5F5F5);
const buyerTint = Color(0xFFFFF0F6);

ThemeData buyerTheme() {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  final text = ThemeData.light().textTheme;
  return ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFE6007A),
          brightness: Brightness.light,
        ).copyWith(
          primary: buyerPink,
          secondary: buyerPurple,
          surface: Colors.white,
          surfaceTint: Colors.transparent,
          surfaceContainerHighest: const Color(0xFFF3F1F3),
          primaryContainer: buyerTint,
          onPrimaryContainer: buyerPink,
          secondaryContainer: const Color(0xFFF3EDF6),
          onSecondaryContainer: buyerPurple,
          onSurface: const Color(0xFF211C23),
          onSurfaceVariant: const Color(0xFF625A61),
          outlineVariant: buyerBorder,
          error: const Color(0xFFB42318),
        ),
    scaffoldBackgroundColor: buyerCanvas,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
      bodySmall: text.bodySmall?.copyWith(
        height: 1.4,
        color: const Color(0xFF625A61),
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF211C23),
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF211C23),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      shape: Border(bottom: BorderSide(color: buyerBorder)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: const BorderSide(color: buyerBorder)),
    ),
    dividerTheme: const DividerThemeData(
      color: buyerBorder,
      space: 24,
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: buyerPurple,
      minVerticalPadding: 12,
      selectedTileColor: buyerTint,
      selectedColor: buyerPink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8B8188)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintStyle: const TextStyle(color: Color(0xFF625A61)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: buyerPink, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? buyerPink
              : const Color(0xFF625A61),
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.fromMap({
        WidgetState.selected: IconThemeData(color: buyerPink),
        WidgetState.any: IconThemeData(color: Color(0xFF625A61)),
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: buyerPink,
      unselectedLabelColor: Color(0xFF625A61),
      indicatorColor: buyerPink,
      dividerColor: buyerBorder,
    ),
  );
}
