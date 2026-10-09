import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A reusable, restrained glassmorphism container that delivers a frosted,
/// translucent look when overlaid on photo headers or rich backgrounds.
///
/// Features:
/// - Isolated in a [RepaintBoundary] to ensure high frame rates (16ms budget).
/// - Automatically disables expensive backdrop filtering when animations are
///   disabled or when [GlassConfig.enabled] is false.
/// - Adheres to [GlassTheme] tokens.
/// - Optional soft specular highlight along the top edge for realism.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.borderRadius,
    this.blur,
    this.tintColor,
    this.borderColor,
    this.borderWidth,
    this.highlightColor,
    this.showTopHighlight = true,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.boxShadow,
    this.alignment,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget? child;
  final BorderRadiusGeometry? borderRadius;
  final double? blur;
  final Color? tintColor;
  final Color? borderColor;
  final double? borderWidth;
  final Color? highlightColor;
  final bool showTopHighlight;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final List<BoxShadow>? boxShadow;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final glassTheme = GlassTheme.of(context);
    final isBlurActive = GlassConfig.isBlurActive(context);

    final resolvedRadius = borderRadius ?? AppRadius.border16;
    final resolvedBlur = blur ?? glassTheme.blur;
    final resolvedBorderColor = borderColor ?? glassTheme.borderColor;
    final resolvedBorderWidth = borderWidth ?? glassTheme.borderWidth;
    final resolvedHighlight = highlightColor ?? glassTheme.highlightColor;

    final resolvedTint = isBlurActive
        ? (tintColor ?? glassTheme.tintColor)
        : (tintColor ?? glassTheme.fallbackColor);

    // Build the decorated surface with border and optional top specular highlight
    Widget surfaceContent = Container(
      width: width,
      height: height,
      constraints: constraints,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        color: showTopHighlight ? null : resolvedTint,
        borderRadius: resolvedRadius,
        border: Border.all(
          color: resolvedBorderColor,
          width: resolvedBorderWidth,
        ),
        gradient: showTopHighlight
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(resolvedHighlight, resolvedTint),
                  resolvedTint,
                ],
                stops: const [0.0, 0.45],
              )
            : null,
      ),
      child: child,
    );

    Widget result;
    if (isBlurActive) {
      // RepaintBoundary isolates blur composition to its own render layer
      result = RepaintBoundary(
        child: ClipRRect(
          borderRadius: resolvedRadius,
          clipBehavior: clipBehavior,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: resolvedBlur,
              sigmaY: resolvedBlur,
            ),
            child: surfaceContent,
          ),
        ),
      );
    } else {
      // Graceful low-perf / reduced-motion fallback without BackdropFilter
      result = ClipRRect(
        borderRadius: resolvedRadius,
        clipBehavior: clipBehavior,
        child: surfaceContent,
      );
    }

    if (boxShadow != null && boxShadow!.isNotEmpty) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: resolvedRadius,
          boxShadow: boxShadow,
        ),
        child: result,
      );
    }

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    return result;
  }
}

/// Circular glass button built specifically for photo headers (back, favorite, share).
///
/// Ensures:
/// - Exact 48x48dp minimum touch target for accessibility and ergonomic tapping.
/// - Crisp semantic labels and tooltip support.
/// - Restrained frosted blur with subtle border.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.tooltip,
    super.key,
    this.onPressed,
    this.iconColor,
    this.iconSize = 20.0,
    this.badge,
    this.semanticsLabel,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final double iconSize;
  final Widget? badge;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    const defaultIconColor = Color(0xFF132219);

    final resolvedIconColor = iconColor ?? defaultIconColor;

    return Semantics(
      button: true,
      label: semanticsLabel ?? tooltip,
      tooltip: tooltip,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: GlassContainer(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              showTopHighlight: true,
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: Center(
                    child: badge != null
                        ? badge!
                        : Icon(
                            icon,
                            size: iconSize,
                            color: resolvedIconColor,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
