import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppCardVariant { elevated, outlined, flat }

class AppCard extends StatefulWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin = EdgeInsets.zero,
    this.variant = AppCardVariant.outlined,
    this.borderRadius = AppRadius.r12,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final AppCardVariant variant;
  final double borderRadius;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = BorderSide(color: theme.colorScheme.outline);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    Color backgroundColor;
    Border? customBorder;
    double elevation;

    switch (widget.variant) {
      case AppCardVariant.elevated:
        backgroundColor = theme.colorScheme.surface;
        customBorder = null;
        elevation = 2;
      case AppCardVariant.outlined:
        backgroundColor = theme.colorScheme.surface;
        customBorder = Border.fromBorderSide(border);
        elevation = 0;
      case AppCardVariant.flat:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        customBorder = null;
        elevation = 0;
    }

    final cardContent = AnimatedScale(
      scale: (_isPressed && widget.onTap != null && !disableAnimations)
          ? 0.97
          : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: customBorder,
          boxShadow: elevation > 0 ? AppShadows.elevated(context) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap != null
                ? (_) => setState(() => _isPressed = true)
                : null,
            onTapUp: widget.onTap != null
                ? (_) => setState(() => _isPressed = false)
                : null,
            onTapCancel: widget.onTap != null
                ? () => setState(() => _isPressed = false)
                : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            splashColor: theme.colorScheme.primary.withAlpha(20),
            highlightColor: theme.colorScheme.primary.withAlpha(10),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );

    return cardContent;
  }
}
