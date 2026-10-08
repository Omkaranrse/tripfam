import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/deck_config.dart';

class DeckActionButtons extends StatelessWidget {
  const DeckActionButtons({
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onViewDetails,
    super.key,
  });

  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve which button is Save and which is Skip based on kSaveDirection
    final isLeftSave = SwipeDirection.left.isSave;

    final leftAction = isLeftSave ? onSwipeLeft : onSwipeLeft;
    final rightAction = isLeftSave ? onSwipeRight : onSwipeRight;

    final leftIcon = isLeftSave ? Icons.bookmark_rounded : Icons.close_rounded;
    final leftTooltip = isLeftSave ? 'Save trip' : 'Skip trip';
    final leftColor = isLeftSave
        ? const Color(0xFFC6E062) // Lime accent
        : (isDark ? const Color(0xFFFF8A65) : const Color(0xFFE64A19));

    final rightIcon = !isLeftSave
        ? Icons.bookmark_rounded
        : Icons.close_rounded;
    final rightTooltip = !isLeftSave ? 'Save trip' : 'Skip trip';
    final rightColor = !isLeftSave
        ? const Color(0xFFC6E062)
        : (isDark ? const Color(0xFFFF8A65) : const Color(0xFFE64A19));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left circular action button (Skip or Save depending on kSaveDirection)
              Semantics(
                button: true,
                label: leftTooltip,
                child: Tooltip(
                  message: leftTooltip,
                  child: Material(
                    color: isDark ? const Color(0xFF1B2B20) : Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1.5,
                    shadowColor: Colors.black.withAlpha(isDark ? 80 : 25),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: leftAction,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: leftColor.withAlpha(90),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(leftIcon, size: 17, color: leftColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Full-width pill "View Details" button in the center
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'View Details',
                  child: SizedBox(
                    height: 36,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 1.5,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      onPressed: onViewDetails,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                      label: const Text(
                        'View Details',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Right circular action button (Save or Skip depending on kSaveDirection)
              Semantics(
                button: true,
                label: rightTooltip,
                child: Tooltip(
                  message: rightTooltip,
                  child: Material(
                    color: isDark ? const Color(0xFF1B2B20) : Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1.5,
                    shadowColor: Colors.black.withAlpha(isDark ? 80 : 25),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: rightAction,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: rightColor.withAlpha(90),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(rightIcon, size: 17, color: rightColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
