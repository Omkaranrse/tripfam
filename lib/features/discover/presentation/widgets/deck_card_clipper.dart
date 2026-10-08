import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/deck_config.dart';

/// Decorative card clipper providing an optional notched top corner or standard rounded rectangle.
class DeckCardClipper extends CustomClipper<Path> {
  const DeckCardClipper({
    this.useNotch = kUseNotchedCardClip,
    this.radius = AppRadius.r28,
  });

  final bool useNotch;
  final double radius;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (!useNotch) {
      // Standard rounded rectangle fallback
      path.addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));
      return path;
    }

    // Modern travel concept notch on top-right corner
    const notchW = 72.0;
    const notchH = 40.0;
    final cornerR = radius;

    path.moveTo(0, cornerR);
    path.arcToPoint(Offset(cornerR, 0), radius: Radius.circular(cornerR));

    // Top edge towards notch
    path.lineTo(size.width - notchW - cornerR, 0);
    path.arcToPoint(
      Offset(size.width - notchW, cornerR),
      radius: Radius.circular(cornerR),
      clockwise: false,
    );
    path.lineTo(size.width - notchW, notchH - cornerR);
    path.arcToPoint(
      Offset(size.width - notchW + cornerR, notchH),
      radius: Radius.circular(cornerR),
    );
    path.lineTo(size.width - cornerR, notchH);
    path.arcToPoint(
      Offset(size.width, notchH + cornerR),
      radius: Radius.circular(cornerR),
    );

    // Right edge
    path.lineTo(size.width, size.height - cornerR);
    path.arcToPoint(
      Offset(size.width - cornerR, size.height),
      radius: Radius.circular(cornerR),
    );

    // Bottom edge
    path.lineTo(cornerR, size.height);
    path.arcToPoint(
      Offset(0, size.height - cornerR),
      radius: Radius.circular(cornerR),
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant DeckCardClipper oldClipper) =>
      oldClipper.useNotch != useNotch || oldClipper.radius != radius;
}
