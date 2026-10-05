import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_tokens.dart';

extension StaggeredEntranceExtension on Widget {
  /// Applies a staggered fade and slide entrance for lists.
  /// Respects [MediaQuery.disableAnimationsOf] and limits animation to [maxAnimatedItems].
  /// Uses [RepaintBoundary] for rendering performance.
  Widget animateEntrance({
    required BuildContext context,
    required int index,
    int maxAnimatedItems = 8,
  }) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations || index >= maxAnimatedItems) {
      return RepaintBoundary(child: this);
    }

    final delay = (index * 40).ms;
    return RepaintBoundary(
      child: animate()
          .fadeIn(
            delay: delay,
            duration: AppMotion.normal,
            curve: AppMotion.curve,
          )
          .slideY(
            begin: 0.10,
            end: 0.0,
            delay: delay,
            duration: AppMotion.normal,
            curve: AppMotion.curve,
          ),
    );
  }
}
