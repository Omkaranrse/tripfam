import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
    this.icon,
    this.small = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final resolvedBg = isSelected
        ? theme.colorScheme.primary
        : (isDark
            ? theme.colorScheme.surfaceContainerHighest.withAlpha(120)
            : const Color(0xFFE3EBE4));

    final resolvedTextColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final resolvedBorder = isSelected
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : Border.all(color: theme.colorScheme.outline.withAlpha(50), width: 1.0);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: AppRadius.borderPill,
      child: AnimatedContainer(
        duration: disableAnimations ? Duration.zero : AppMotion.fast,
        curve: AppMotion.curve,
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 16,
          vertical: small ? 6 : 9,
        ),
        decoration: BoxDecoration(
          color: resolvedBg,
          borderRadius: AppRadius.borderPill,
          border: resolvedBorder,
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withAlpha(35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: small ? 14 : 16,
                color: resolvedTextColor,
              ),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: disableAnimations ? Duration.zero : AppMotion.fast,
              curve: AppMotion.curve,
              style: (small ? AppTypography.caption : AppTypography.label).copyWith(
                color: resolvedTextColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
