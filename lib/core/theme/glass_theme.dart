import 'dart:ui';
import 'package:flutter/material.dart';

/// Global configuration and toggles for glassmorphism effects across TripMate.
abstract final class GlassConfig {
  /// Global kill-switch for glassmorphism backdrop blur.
  /// When set to false, widgets fall back to solid/semi-translucent surfaces.
  static bool enabled = true;

  /// Determines if backdrop filter blur should be rendered for the given context.
  /// Honors global switch and user accessibility preferences (e.g. reduced motion).
  static bool isBlurActive(BuildContext context) {
    if (!enabled) return false;
    if (MediaQuery.disableAnimationsOf(context)) return false;
    return true;
  }
}

/// ThemeExtension defining design tokens for glassmorphism surfaces.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({
    required this.tintColor,
    required this.borderColor,
    required this.highlightColor,
    required this.fallbackColor,
    this.blur = 16.0,
    this.borderWidth = 1.0,
  });

  /// The translucent tint overlaid on top of the blurred backdrop.
  final Color tintColor;

  /// The subtle 1px border stroke color defining the glass surface boundary.
  final Color borderColor;

  /// The subtle top edge highlight simulating ambient light reflection.
  final Color highlightColor;

  /// Solid or high-opacity fallback color used when backdrop blur is disabled.
  final Color fallbackColor;

  /// Blur intensity (sigmaX and sigmaY). Default is 16.0.
  final double blur;

  /// Border stroke width. Default is 1.0.
  final double borderWidth;

  /// Light theme preset: frosted crystalline with soft white reflection.
  static const GlassTheme light = GlassTheme(
    tintColor: Color(0xCCFFFFFF), // 80% opacity frost
    borderColor: Color(0x66FFFFFF), // 40% white edge
    highlightColor: Color(0x99FFFFFF), // 60% top reflection
    fallbackColor: Color(0xF5F7FAF6), // crisp surface fallback
    blur: 16.0,
    borderWidth: 1.0,
  );

  /// Convenience lookup with automatic fallback if not registered in theme.
  static GlassTheme of(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<GlassTheme>();
    if (ext != null) return ext;
    return light;
  }

  @override
  GlassTheme copyWith({
    Color? tintColor,
    Color? borderColor,
    Color? highlightColor,
    Color? fallbackColor,
    double? blur,
    double? borderWidth,
  }) {
    return GlassTheme(
      tintColor: tintColor ?? this.tintColor,
      borderColor: borderColor ?? this.borderColor,
      highlightColor: highlightColor ?? this.highlightColor,
      fallbackColor: fallbackColor ?? this.fallbackColor,
      blur: blur ?? this.blur,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  @override
  GlassTheme lerp(ThemeExtension<GlassTheme>? other, double t) {
    if (other is! GlassTheme) return this;
    return GlassTheme(
      tintColor: Color.lerp(tintColor, other.tintColor, t) ?? tintColor,
      borderColor: Color.lerp(borderColor, other.borderColor, t) ?? borderColor,
      highlightColor:
          Color.lerp(highlightColor, other.highlightColor, t) ?? highlightColor,
      fallbackColor:
          Color.lerp(fallbackColor, other.fallbackColor, t) ?? fallbackColor,
      blur: lerpDouble(blur, other.blur, t) ?? blur,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t) ?? borderWidth,
    );
  }
}
