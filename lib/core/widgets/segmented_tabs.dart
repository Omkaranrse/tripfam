import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Fluid segmented control with an animated sliding thumb.
/// Fits compact, medium, and expanded viewports without truncation.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
    this.height = 44.0,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final containerBg = isDark
        ? const Color(0xFF101C15)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(120);

    final thumbColor = isDark
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;

    final selectedTextColor = isDark
        ? const Color(0xFF071E12)
        : theme.colorScheme.primary;

    final unselectedTextColor = theme.colorScheme.onSurface.withAlpha(170);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final count = tabs.length;
        if (count == 0) return const SizedBox.shrink();
        final tabWidth = (totalWidth - 6.0) / count;

        return Container(
          height: height,
          width: totalWidth,
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: AppRadius.borderPill,
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(18)
                  : theme.colorScheme.outlineVariant.withAlpha(80),
            ),
          ),
          child: Stack(
            children: [
              // Sliding Thumb Indicator
              AnimatedPositioned(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: thumbColor,
                    borderRadius: AppRadius.borderPill,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 50 : 20),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Tab text triggers
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (selectedIndex != i) {
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            style: AppTypography.cardTitle.copyWith(
                              fontSize: 14,
                              fontWeight: selectedIndex == i
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: selectedIndex == i
                                  ? selectedTextColor
                                  : unselectedTextColor,
                            ),
                            child: Text(
                              tabs[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      },
    );
  }
}
