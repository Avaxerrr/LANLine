import 'package:flutter/material.dart';

class AppTheme {
  static const _brand = Color(0xFF5B8CFF);
  static const _darkBackground = Color(0xFF0D1118);
  static const _darkSurface = Color(0xFF151B26);
  static const _darkSurfaceAlt = Color(0xFF1A2432);
  static const _darkBorder = Color(0xFF243244);
  static const _darkTextMuted = Color(0xFF98A4B8);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.dark,
      surface: _darkSurface,
    ),
    scaffoldBackgroundColor: _darkBackground,
    canvasColor: _darkBackground,
    dividerColor: _darkBorder,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: _darkSurface.withValues(alpha: 0.9),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: _darkBorder),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      textColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: _darkSurface,
      indicatorColor: _brand.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? Colors.white : _darkTextMuted,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? _brand : _darkTextMuted,
          size: 21,
        );
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 78,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
      bodyMedium: TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
      bodySmall: TextStyle(color: _darkTextMuted, fontSize: 12, height: 1.3),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurfaceAlt,
      hintStyle: const TextStyle(color: _darkTextMuted),
      labelStyle: const TextStyle(color: _darkTextMuted),
      prefixIconColor: _darkTextMuted,
      suffixIconColor: _darkTextMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _brand, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: _darkBorder),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _darkSurfaceAlt,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(color: _darkTextMuted, height: 1.4),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _brand),
    popupMenuTheme: PopupMenuThemeData(
      color: _darkSurfaceAlt,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(color: Colors.white),
    ),
  );
}
