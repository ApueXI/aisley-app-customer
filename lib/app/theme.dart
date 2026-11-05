import 'package:flutter/material.dart';

const buyerPink = Color(0xFFB60060);
const buyerPurple = Color(0xFF4C1268);
const buyerBorder = Color(0xFFE4DFE3);
const buyerCanvas = Color(0xFFF5F5F5);
const buyerTint = Color(0xFFFFF0F6);

ThemeData buyerTheme([Brightness brightness = Brightness.light]) {
  final dark = brightness == Brightness.dark;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  final text = ThemeData(brightness: brightness).textTheme;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFE6007A),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFFF85BD) : buyerPink,
        onPrimary: dark ? const Color(0xFF4C0029) : Colors.white,
        secondary: dark ? const Color(0xFFDCB0F1) : buyerPurple,
        onSecondary: dark ? const Color(0xFF351047) : Colors.white,
        surface: dark ? const Color(0xFF211D22) : Colors.white,
        surfaceTint: Colors.transparent,
        surfaceContainerHighest: dark
            ? const Color(0xFF302A31)
            : const Color(0xFFF3F1F3),
        primaryContainer: dark ? const Color(0xFF55203D) : buyerTint,
        onPrimaryContainer: dark ? const Color(0xFFFFD9E9) : buyerPink,
        secondaryContainer: dark
            ? const Color(0xFF422B4D)
            : const Color(0xFFF3EDF6),
        onSecondaryContainer: dark ? const Color(0xFFF3DAFF) : buyerPurple,
        onSurface: dark ? const Color(0xFFF0E8EF) : const Color(0xFF211C23),
        onSurfaceVariant: dark
            ? const Color(0xFFCFC2CD)
            : const Color(0xFF625A61),
        outlineVariant: dark ? const Color(0xFF4A424B) : buyerBorder,
        error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFB42318),
      );
  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF141218) : buyerCanvas,
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
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 24,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.secondary,
      minVerticalPadding: 12,
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: dark ? scheme.outline : const Color(0xFF8B8188),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
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
      side: BorderSide(color: scheme.outlineVariant),
      selectedColor: dark ? scheme.primaryContainer : const Color(0xFFFCE8F2),
      labelStyle: TextStyle(color: scheme.secondary),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      iconTheme: WidgetStateProperty.fromMap({
        WidgetState.selected: IconThemeData(color: scheme.primary),
        WidgetState.any: IconThemeData(color: scheme.onSurfaceVariant),
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: scheme.outlineVariant,
    ),
  );
}
