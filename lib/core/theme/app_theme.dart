import 'package:flutter/material.dart';

import 'app_tokens.dart';

export 'app_tokens.dart';

abstract final class AppTheme {
  // Soft Sage-Green Travel UI Light Palette
  static const _lightBackground = Color(0xFFF3F6F1);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightPrimary = Color(0xFF28543E); // Soft refined deep sage
  static const _lightSecondary = Color(0xFF436E58); // Muted forest sage
  static const _lightTertiary = Color(0xFF88AB2A); // Soft lime accent
  static const _lightText = Color(0xFF132219);
  static const _lightBorder = Color(0xFFD8E2D8);

  // Soft Sage-Green Travel UI Dark Palette (Forest Obsidian)
  static const _darkBackground = Color(0xFF0F1813);
  static const _darkSurface = Color(0xFF16241C);
  static const _darkPrimary = Color(0xFF7FA88B); // Luminous soft sage
  static const _darkSecondary = Color(0xFF98C1A5);
  static const _darkTertiary = Color(0xFFC6E062); // Lime accent
  static const _darkText = Color(0xFFF1F6F2);
  static const _darkBorder = Color(0xFF233529);

  static const darkForestSurfaceLight = Color(0xFF15261D);
  static const darkForestSurfaceDark = Color(0xFF101C15);

  static Color darkForest(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkForestSurfaceDark
        : darkForestSurfaceLight;
  }

  static const Color lime = Color(0xFFC6E062);

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    background: _lightBackground,
    surface: _lightSurface,
    primary: _lightPrimary,
    secondary: _lightSecondary,
    tertiary: _lightTertiary,
    text: _lightText,
    border: _lightBorder,
  );

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    background: _darkBackground,
    surface: _darkSurface,
    primary: _darkPrimary,
    secondary: _darkSecondary,
    tertiary: _darkTertiary,
    text: _darkText,
    border: _darkBorder,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color primary,
    required Color secondary,
    required Color tertiary,
    required Color text,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: isDark ? const Color(0xFF071E12) : Colors.white,
      secondary: secondary,
      onSecondary: isDark ? const Color(0xFF0B2115) : Colors.white,
      tertiary: tertiary,
      onTertiary: const Color(0xFF152B05),
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: surface,
      onSurface: text,
      inverseSurface: isDark ? const Color(0xFFF1F6F2) : darkForestSurfaceLight,
      onInverseSurface: isDark ? darkForestSurfaceLight : const Color(0xFFF1F6F2),
      outline: border,
      outlineVariant: border,
      primaryContainer: isDark ? const Color(0xFF1E3526) : const Color(0xFFD8EADB),
      onPrimaryContainer: isDark ? const Color(0xFFC7E2CE) : const Color(0xFF103622),
      surfaceContainerHighest: isDark
          ? const Color(0xFF223428)
          : const Color(0xFFE5EDE4),
    );

    // Poppins type scale:
    // headline 28/600, title 20/600, card title 16/500, body 14/400, caption 12/400
    final textTheme = TextTheme(
      headlineLarge: AppTypography.headline.copyWith(color: text),
      headlineMedium: AppTypography.headline.copyWith(color: text),
      titleLarge: AppTypography.title.copyWith(color: text),
      titleMedium: AppTypography.cardTitle.copyWith(color: text),
      titleSmall: AppTypography.cardTitle.copyWith(color: text),
      bodyLarge: AppTypography.body.copyWith(color: text),
      bodyMedium: AppTypography.body.copyWith(color: text),
      bodySmall: AppTypography.caption.copyWith(
        color: text.withAlpha(isDark ? 180 : 160),
      ),
      labelLarge: AppTypography.cardTitle.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: AppTypography.body.copyWith(
        color: text.withAlpha(isDark ? 200 : 180),
      ),
      labelSmall: AppTypography.caption.copyWith(
        color: text.withAlpha(isDark ? 180 : 160),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.border12,
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: const Color(0xFFC6E062).withAlpha(45),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: const Color(0xFFC6E062),
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(color: Colors.white.withAlpha(170));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFC6E062), size: 22);
          }
          return IconThemeData(color: Colors.white.withAlpha(170), size: 22);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primary.withAlpha(isDark ? 50 : 30),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: text.withAlpha(160)),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: text.withAlpha(160),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF16202C) : const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class AppSemanticColors {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.onError,
    required this.info,
    required this.onInfo,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color error;
  final Color onError;
  final Color info;
  final Color onInfo;

  static const light = AppSemanticColors(
    success: Color(0xFF286544), // Harmonized sage green (contrast 5.8:1)
    onSuccess: Colors.white,
    warning: Color(0xFF8D5B00), // Harmonized warm amber (contrast 5.2:1)
    onWarning: Colors.white,
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    info: Color(0xFF235A6D),
    onInfo: Colors.white,
  );

  static const dark = AppSemanticColors(
    success: Color(0xFF81C784), // Harmonized luminous sage green (contrast 8.7:1)
    onSuccess: Color(0xFF0C2413),
    warning: Color(0xFFFFB74D), // Harmonized luminous amber (contrast 10.4:1)
    onWarning: Color(0xFF331D00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    info: Color(0xFF80D4EA),
    onInfo: Color(0xFF003644),
  );

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
