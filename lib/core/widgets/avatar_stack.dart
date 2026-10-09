import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Renders an avatar stack respecting privacy requirements:
/// Only shows member photos to signed-in, verified users.
/// Otherwise, gracefully displays a clean themed member count badge.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    required this.totalMembers,
    super.key,
    this.avatarUrls = const [],
    this.isVerifiedViewer = false,
    this.avatarSize = 28.0,
    this.borderColor,
    this.badgeBackgroundColor,
    this.textColor,
    this.maxVisible = 3,
  });

  final List<String?> avatarUrls;
  final int totalMembers;
  final bool isVerifiedViewer;
  final double avatarSize;
  final Color? borderColor;
  final Color? badgeBackgroundColor;
  final Color? textColor;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedBorder = borderColor ?? theme.colorScheme.surface;
    final resolvedText = textColor ?? theme.colorScheme.onSurface;

    // Filter out null/empty avatar URLs (e.g. members who did not opt in)
    final validAvatars = avatarUrls
        .where((url) => url != null && url.trim().isNotEmpty)
        .toList();

    // Privacy rule: show photos only to signed-in verified users, and only if photos exist
    final shouldShowPhotos = isVerifiedViewer && validAvatars.isNotEmpty;

    if (!shouldShowPhotos) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: badgeBackgroundColor ??
              theme.colorScheme.surfaceContainerHighest.withAlpha(150),
          borderRadius: AppRadius.borderPill,
          border: Border.all(
            color: resolvedBorder.withAlpha(80),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_rounded,
              size: 14,
              color: resolvedText.withAlpha(200),
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              '$totalMembers',
              style: AppTypography.caption.copyWith(
                color: resolvedText,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    final visibleAvatars = validAvatars.take(maxVisible).toList();
    final remainingCount = totalMembers - visibleAvatars.length;
    final overlap = avatarSize * 0.65;

    final items = <Widget>[];

    for (var i = 0; i < visibleAvatars.length; i++) {
      final url = visibleAvatars[i]!;
      items.add(
        Positioned(
          left: i * overlap,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: resolvedBorder, width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildFallback(theme, resolvedText),
              ),
            ),
          ),
        ),
      );
    }

    if (remainingCount > 0) {
      items.add(
        Positioned(
          left: visibleAvatars.length * overlap,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
              border: Border.all(color: resolvedBorder, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '+$remainingCount',
              style: TextStyle(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    final totalWidth = (visibleAvatars.length + (remainingCount > 0 ? 1 : 0) - 1) *
            overlap +
        avatarSize;

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(children: items),
    );
  }

  Widget _buildFallback(ThemeData theme, Color textCol) {
    return Container(
      color: theme.colorScheme.primary.withAlpha(40),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: avatarSize * 0.6,
        color: textCol,
      ),
    );
  }
}
