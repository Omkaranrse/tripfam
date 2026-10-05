import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum StatusPillTone {
  success,
  warning,
  error,
  info,
  neutral,
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    super.key,
    this.tone = StatusPillTone.neutral,
    this.icon,
    this.showDot = true,
  });

  final String label;
  final StatusPillTone tone;
  final IconData? icon;
  final bool showDot;

  factory StatusPill.fromStatus(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('confirm') ||
        lower.contains('safe') ||
        lower.contains('verif') ||
        lower.contains('accept')) {
      return StatusPill(label: status, tone: StatusPillTone.success);
    }
    if (lower.contains('pend') ||
        lower.contains('wait') ||
        lower.contains('review') ||
        lower.contains('intro')) {
      return StatusPill(label: status, tone: StatusPillTone.warning);
    }
    if (lower.contains('cancel') ||
        lower.contains('reject') ||
        lower.contains('expire')) {
      return StatusPill(label: status, tone: StatusPillTone.error);
    }
    if (lower.contains('active') || lower.contains('depart')) {
      return StatusPill(label: status, tone: StatusPillTone.info);
    }
    return StatusPill(label: status, tone: StatusPillTone.neutral);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    switch (tone) {
      case StatusPillTone.success:
        color = semantic.success;
      case StatusPillTone.warning:
        color = semantic.warning;
      case StatusPillTone.error:
        color = semantic.error;
      case StatusPillTone.info:
        color = semantic.info;
      case StatusPillTone.neutral:
        color = theme.colorScheme.onSurface.withAlpha(160);
    }

    final bgColor = color.withAlpha(isDark ? 35 : 22);
    final borderColor = color.withAlpha(isDark ? 80 : 50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
