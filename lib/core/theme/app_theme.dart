import 'package:flutter/material.dart';

enum AppThemePreset { midnight, graphite, forest }

extension AppThemePresetX on AppThemePreset {
  String get storageValue => switch (this) {
    AppThemePreset.midnight => 'midnight',
    AppThemePreset.graphite => 'graphite',
    AppThemePreset.forest => 'forest',
  };

  String get label => switch (this) {
    AppThemePreset.midnight => 'Midnight',
    AppThemePreset.graphite => 'Graphite',
    AppThemePreset.forest => 'Forest',
  };

  String get description => switch (this) {
    AppThemePreset.midnight => 'Blue-black and luminous',
    AppThemePreset.graphite => 'Neutral, minimal, restrained',
    AppThemePreset.forest => 'Deep green and calm',
  };

  static AppThemePreset fromStorage(String? value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => AppThemePreset.midnight,
    );
  }
}

@immutable
class AppThemePalette extends ThemeExtension<AppThemePalette> {
  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceMuted;
  final Color border;
  final Color textMuted;
  final Color brand;
  final Color groupAccent;
  final Color positive;
  final Color warning;
  final Color danger;
  final Color navGlass;
  final Color inputFill;
  final Color menuSurface;

  const AppThemePalette({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceMuted,
    required this.border,
    required this.textMuted,
    required this.brand,
    required this.groupAccent,
    required this.positive,
    required this.warning,
    required this.danger,
    required this.navGlass,
    required this.inputFill,
    required this.menuSurface,
  });

  static AppThemePalette fromPreset(AppThemePreset preset) => switch (preset) {
    AppThemePreset.midnight => const AppThemePalette(
      background: Color(0xFF080E15),
      backgroundAlt: Color(0xFF101826),
      surface: Color(0xFF162131),
      surfaceRaised: Color(0xFF253349),
      surfaceMuted: Color(0xFF111927),
      border: Color(0xFF314256),
      textMuted: Color(0xFF95A3B8),
      brand: Color(0xFF6C95FF),
      groupAccent: Color(0xFFE2B443),
      positive: Color(0xFF4DE1A7),
      warning: Color(0xFFFFB866),
      danger: Color(0xFFFF6E74),
      navGlass: Color(0xCC101722),
      inputFill: Color(0xFF131C29),
      menuSurface: Color(0xFF1A2638),
    ),
    AppThemePreset.graphite => const AppThemePalette(
      background: Color(0xFF0D0F13),
      backgroundAlt: Color(0xFF171A20),
      surface: Color(0xFF1B2028),
      surfaceRaised: Color(0xFF252C36),
      surfaceMuted: Color(0xFF14181F),
      border: Color(0xFF303846),
      textMuted: Color(0xFFA2A9B7),
      brand: Color(0xFF82A1FF),
      groupAccent: Color(0xFFE0BE74),
      positive: Color(0xFF67D2A7),
      warning: Color(0xFFFFBC73),
      danger: Color(0xFFFF7D7D),
      navGlass: Color(0xCC181C23),
      inputFill: Color(0xFF161A21),
      menuSurface: Color(0xFF232934),
    ),
    AppThemePreset.forest => const AppThemePalette(
      background: Color(0xFF0A1211),
      backgroundAlt: Color(0xFF12201D),
      surface: Color(0xFF172722),
      surfaceRaised: Color(0xFF22352F),
      surfaceMuted: Color(0xFF111C19),
      border: Color(0xFF30453F),
      textMuted: Color(0xFF9AB0A9),
      brand: Color(0xFF78B7FF),
      groupAccent: Color(0xFFE2C164),
      positive: Color(0xFF57D8A0),
      warning: Color(0xFFFFBF6F),
      danger: Color(0xFFFF7E7B),
      navGlass: Color(0xCC162421),
      inputFill: Color(0xFF13211E),
      menuSurface: Color(0xFF20312D),
    ),
  };

  LinearGradient get surfaceGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      surfaceRaised.withValues(alpha: 0.92),
      surface.withValues(alpha: 0.96),
    ],
  );

  LinearGradient get pageGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundAlt, background],
    stops: const [0.0, 0.7],
  );

  @override
  AppThemePalette copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceMuted,
    Color? border,
    Color? textMuted,
    Color? brand,
    Color? groupAccent,
    Color? positive,
    Color? warning,
    Color? danger,
    Color? navGlass,
    Color? inputFill,
    Color? menuSurface,
  }) {
    return AppThemePalette(
      background: background ?? this.background,
      backgroundAlt: backgroundAlt ?? this.backgroundAlt,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      groupAccent: groupAccent ?? this.groupAccent,
      positive: positive ?? this.positive,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      navGlass: navGlass ?? this.navGlass,
      inputFill: inputFill ?? this.inputFill,
      menuSurface: menuSurface ?? this.menuSurface,
    );
  }

  @override
  AppThemePalette lerp(ThemeExtension<AppThemePalette>? other, double t) {
    if (other is! AppThemePalette) {
      return this;
    }

    return AppThemePalette(
      background: Color.lerp(background, other.background, t) ?? background,
      backgroundAlt:
          Color.lerp(backgroundAlt, other.backgroundAlt, t) ?? backgroundAlt,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceRaised:
          Color.lerp(surfaceRaised, other.surfaceRaised, t) ?? surfaceRaised,
      surfaceMuted:
          Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      brand: Color.lerp(brand, other.brand, t) ?? brand,
      groupAccent: Color.lerp(groupAccent, other.groupAccent, t) ?? groupAccent,
      positive: Color.lerp(positive, other.positive, t) ?? positive,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      navGlass: Color.lerp(navGlass, other.navGlass, t) ?? navGlass,
      inputFill: Color.lerp(inputFill, other.inputFill, t) ?? inputFill,
      menuSurface: Color.lerp(menuSurface, other.menuSurface, t) ?? menuSurface,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppThemePalette get appPalette =>
      Theme.of(this).extension<AppThemePalette>()!;
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B8CFF),
      brightness: Brightness.light,
    ),
  );

  static ThemeData darkTheme(AppThemePreset preset) {
    final palette = AppThemePalette.fromPreset(preset);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.brand,
        brightness: Brightness.dark,
        surface: palette.surface,
        primary: palette.brand,
        secondary: palette.groupAccent,
      ),
      extensions: [palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      dividerColor: palette.border,
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
        color: palette.surface.withValues(alpha: 0.92),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: palette.border.withValues(alpha: 0.22)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.brand.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? Colors.white : palette.textMuted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? palette.brand : palette.textMuted,
            size: 21,
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 78,
      ),
      textTheme: TextTheme(
        headlineSmall: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleMedium: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.35,
        ),
        bodyMedium: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.35,
        ),
        bodySmall: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          height: 1.3,
        ),
        labelMedium: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          height: 1.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputFill.withValues(alpha: 0.92),
        hintStyle: TextStyle(color: palette.textMuted),
        labelStyle: TextStyle(color: palette.textMuted),
        prefixIconColor: palette.textMuted,
        suffixIconColor: palette.textMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.border.withValues(alpha: 0.28)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.border.withValues(alpha: 0.28)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: palette.brand.withValues(alpha: 0.9),
            width: 1.35,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: palette.border),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceRaised,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: palette.textMuted, height: 1.4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.menuSurface,
        modalBackgroundColor: palette.menuSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.brand),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.menuSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
