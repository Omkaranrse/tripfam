import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_tokens.dart';

/// Page transition using shared-axis (subtle horizontal slide + fade) for pushed screens.
/// Respects [MediaQuery.disableAnimationsOf].
class SharedAxisPage<T> extends CustomTransitionPage<T> {
  SharedAxisPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           if (MediaQuery.disableAnimationsOf(context)) {
             return child;
           }

           final curvedAnimation = CurvedAnimation(
             parent: animation,
             curve: AppMotion.curve,
           );

           final slideAnimation = Tween<Offset>(
             begin: const Offset(0.06, 0.0),
             end: Offset.zero,
           ).animate(curvedAnimation);

           final fadeAnimation = Tween<double>(
             begin: 0.0,
             end: 1.0,
           ).animate(curvedAnimation);

           return SlideTransition(
             position: slideAnimation,
             child: FadeTransition(opacity: fadeAnimation, child: child),
           );
         },
         transitionDuration: AppMotion.normal,
         reverseTransitionDuration: AppMotion.fast,
       );
}

/// Page transition using fade-through for top-level tab changes.
/// Respects [MediaQuery.disableAnimationsOf].
class FadeThroughPage<T> extends CustomTransitionPage<T> {
  FadeThroughPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           if (MediaQuery.disableAnimationsOf(context)) {
             return child;
           }

           final fadeIn = CurvedAnimation(
             parent: animation,
             curve: const Interval(0.2, 1.0, curve: AppMotion.curve),
           );

           final scaleIn = Tween<double>(begin: 0.98, end: 1.0).animate(
             CurvedAnimation(
               parent: animation,
               curve: const Interval(0.2, 1.0, curve: AppMotion.curve),
             ),
           );

           return FadeTransition(
             opacity: fadeIn,
             child: ScaleTransition(scale: scaleIn, child: child),
           );
         },
         transitionDuration: AppMotion.normal,
       );
}
