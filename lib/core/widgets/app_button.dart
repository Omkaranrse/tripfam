import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.isPill = false,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final bool isPill;
  final BorderRadius? borderRadius;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final padding = switch (widget.size) {
      AppButtonSize.small => const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      AppButtonSize.medium => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      AppButtonSize.large => const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
    };

    final fontSize = switch (widget.size) {
      AppButtonSize.small => 13.0,
      AppButtonSize.medium => 15.0,
      AppButtonSize.large => 16.0,
    };

    final resolvedBorderRadius = widget.borderRadius ??
        (widget.isPill ? AppRadius.borderPill : AppRadius.border12);

    final childWidget = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: fontSize + 2,
            height: fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.variant == AppButtonVariant.primary
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: fontSize + 4),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );

    Widget button;
    switch (widget.variant) {
      case AppButtonVariant.primary:
        button = FilledButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: padding,
            shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
          ),
          child: childWidget,
        );
      case AppButtonVariant.secondary:
        button = FilledButton.tonal(
          onPressed: isEnabled ? widget.onPressed : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: padding,
            shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
          ),
          child: childWidget,
        );
      case AppButtonVariant.outlined:
        button = OutlinedButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: padding,
            shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
          ),
          child: childWidget,
        );
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isEnabled ? widget.onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: padding,
            shape: RoundedRectangleBorder(borderRadius: resolvedBorderRadius),
          ),
          child: childWidget,
        );
    }

    Widget content = Listener(
      onPointerDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onPointerUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onPointerCancel: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: (_isPressed && isEnabled && !disableAnimations) ? 0.97 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: button,
      ),
    );

    if (widget.isFullWidth) {
      return SizedBox(width: double.infinity, child: content);
    }
    return content;
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.medium,
    this.isPill = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonSize size;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      size: size,
      isPill: isPill,
      variant: AppButtonVariant.primary,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.size = AppButtonSize.medium,
    this.isPill = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonSize size;
  final bool isPill;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      size: size,
      isPill: isPill,
      variant: AppButtonVariant.secondary,
    );
  }
}

