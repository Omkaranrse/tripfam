import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s48 = 48.0;
  static const double s64 = 64.0;
  static const double s80 = 80.0;

  /// Unified page-padding token: 20 compact (<600), 32 medium (600-1024), 48 expanded (>1024)
  static double pagePadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600.0) return 20.0;
    if (width < 1024.0) return 32.0;
    return 48.0;
  }

  static EdgeInsets pagePaddingInsets(
    BuildContext context, {
    double vertical = 16.0,
  }) {
    return EdgeInsets.symmetric(
      horizontal: pagePadding(context),
      vertical: vertical,
    );
  }
}

abstract final class AppRadius {
  static const double r12 = 12.0;
  static const Radius radius12 = Radius.circular(r12);
  static const BorderRadius border12 = BorderRadius.all(radius12);

  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r28 = 28.0;
  static const double r32 = 32.0;
  static const double pill = 999.0;

  static const BorderRadius border16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius border20 = BorderRadius.all(Radius.circular(r20));
  static const BorderRadius border24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius border28 = BorderRadius.all(Radius.circular(r28));
  static const BorderRadius border32 = BorderRadius.all(Radius.circular(r32));
  static const BorderRadius borderPill = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppMotion {
  // Fast 150ms, normal 280ms, slow 420ms
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 420);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve gentleSpring = Curves.easeOutBack;
}

abstract final class AppShadows {
  // Tinted layered shadows (palette-colored sage/forest, no glow)
  static List<BoxShadow> subtle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? const Color(0xFF08130B).withAlpha(140)
            : const Color(0xFF28543E).withAlpha(16),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];
  }

  static List<BoxShadow> elevated(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? const Color(0xFF040A06).withAlpha(180)
            : const Color(0xFF28543E).withAlpha(22),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: isDark
            ? const Color(0xFF08130B).withAlpha(100)
            : const Color(0xFF132219).withAlpha(10),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> floating(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: isDark
            ? const Color(0xFF020704).withAlpha(220)
            : const Color(0xFF28543E).withAlpha(30),
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: isDark
            ? const Color(0xFF08130B).withAlpha(120)
            : const Color(0xFF132219).withAlpha(14),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ];
  }
}

abstract final class AppTypography {
  // Poppins type scale: display 32/700, headline 28/600, title 20/600, card title 16/500, label 13/600, body 14/400, caption 12/400
  static const TextStyle display = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
  );

  static const TextStyle headline = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.4,
  );

  static const TextStyle title = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle displayStyle(BuildContext context) =>
      display.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle headlineStyle(BuildContext context) =>
      headline.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle titleStyle(BuildContext context) =>
      title.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle cardTitleStyle(BuildContext context) =>
      cardTitle.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle bodyStyle(BuildContext context) =>
      body.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static TextStyle captionStyle(BuildContext context) =>
      caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
}
