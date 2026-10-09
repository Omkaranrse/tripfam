import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'glass_container.dart';

enum InfoChipVariant {
  scrim, // Translucent dark for photo overlay (contrast >= 4.5:1)
  surface, // Theme-aware surface container
  outline, // Thin outline
  glass, // Frosted glassmorphism for photo overlay
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    required this.label,
    super.key,
    this.icon,
    this.variant = InfoChipVariant.surface,
    this.iconColor,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final InfoChipVariant variant;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (variant == InfoChipVariant.glass) {
      final resolvedText = textColor ?? Colors.white;
      final resolvedIcon = iconColor ?? const Color(0xFFC6E062);

      return GlassContainer(
        borderRadius: AppRadius.borderPill,
        blur: 14.0,
        tintColor: Colors.black.withAlpha(70),
        borderColor: Colors.white.withAlpha(50),
        highlightColor: Colors.white.withAlpha(60),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        showTopHighlight: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: resolvedIcon),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  color: resolvedText,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }

    Color bg;
    Border? border;
    Color resolvedText;
    Color resolvedIcon;

    switch (variant) {
      case InfoChipVariant.glass:
        // Handled above
        bg = Colors.transparent;
        resolvedText = Colors.white;
        resolvedIcon = const Color(0xFFC6E062);
      case InfoChipVariant.scrim:
        bg = Colors.black.withAlpha(100);
        border = Border.all(color: Colors.white.withAlpha(40));
        resolvedText = textColor ?? Colors.white;
        resolvedIcon = iconColor ?? const Color(0xFFC6E062); // Lime accent
      case InfoChipVariant.surface:
        bg = const Color(0xFFE5EDE6);
        border = Border.all(color: theme.colorScheme.outline.withAlpha(40));
        resolvedText = textColor ?? theme.colorScheme.onSurface;
        resolvedIcon = iconColor ?? theme.colorScheme.primary;
      case InfoChipVariant.outline:
        bg = Colors.transparent;
        border = Border.all(color: theme.colorScheme.outline.withAlpha(80));
        resolvedText = textColor ?? theme.colorScheme.onSurface;
        resolvedIcon = iconColor ?? theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderPill,
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: resolvedIcon),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: resolvedText,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
