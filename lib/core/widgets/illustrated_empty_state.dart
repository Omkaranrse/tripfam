import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';

enum EmptyIllustrationType {
  departures,
  requests,
  chats,
  safety,
  generic,
}

class IllustratedEmptyState extends StatelessWidget {
  const IllustratedEmptyState({
    required this.title,
    super.key,
    this.message,
    this.type = EmptyIllustrationType.departures,
    this.actionLabel,
    this.onActionPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
  });

  final String title;
  final String? message;
  final EmptyIllustrationType type;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Custom vector illustration in brand colors
            SizedBox(
              width: 140,
              height: 120,
              child: CustomPaint(
                painter: _BrandIllustrationPainter(
                  type: type,
                  primaryColor: theme.colorScheme.primary,
                  accentColor: const Color(0xFFC6E062), // Lime accent
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text(
              title,
              style: AppTypography.titleStyle(context).copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.s8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  message!,
                  style: AppTypography.bodyStyle(context).copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: AppSpacing.s24),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onActionPressed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandIllustrationPainter extends CustomPainter {
  const _BrandIllustrationPainter({
    required this.type,
    required this.primaryColor,
    required this.accentColor,
  });

  final EmptyIllustrationType type;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final basePaint = Paint()
      ..color = primaryColor.withAlpha(20)
      ..style = PaintingStyle.fill;

    final primaryLine = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // Background soft oval aura
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.55),
        width: w * 0.9,
        height: h * 0.7,
      ),
      basePaint,
    );

    switch (type) {
      case EmptyIllustrationType.departures:
        // Mountain peaks & compass needle
        final mtnPath = Path()
          ..moveTo(w * 0.15, h * 0.8)
          ..lineTo(w * 0.42, h * 0.35)
          ..lineTo(w * 0.58, h * 0.55)
          ..lineTo(w * 0.75, h * 0.28)
          ..lineTo(w * 0.92, h * 0.8)
          ..close();

        canvas.drawPath(
          mtnPath,
          Paint()
            ..color = primaryColor.withAlpha(35)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(mtnPath, primaryLine);

        // Accent sun/compass point
        canvas.drawCircle(Offset(w * 0.75, h * 0.18), 7, accentPaint);

        // Winding trail line
        final trail = Path()
          ..moveTo(w * 0.35, h * 0.82)
          ..quadraticBezierTo(w * 0.48, h * 0.72, w * 0.52, h * 0.84)
          ..quadraticBezierTo(w * 0.58, h * 0.92, w * 0.7, h * 0.85);
        canvas.drawPath(
          trail,
          primaryLine..strokeWidth = 2.0,
        );

      case EmptyIllustrationType.requests:
        // Boarding pass / ticket geometry
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(w * 0.5, h * 0.52),
            width: w * 0.65,
            height: h * 0.60,
          ),
          const Radius.circular(16),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..color = primaryColor.withAlpha(30)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(rect, primaryLine);

        // Ticket notch cutout
        canvas.drawCircle(
          Offset(w * 0.175, h * 0.52),
          8,
          Paint()..color = const Color(0xFFF3F6F1),
        );
        canvas.drawCircle(
          Offset(w * 0.825, h * 0.52),
          8,
          Paint()..color = const Color(0xFFF3F6F1),
        );

        // Dashed fold line
        final dashPaint = Paint()
          ..color = primaryColor.withAlpha(120)
          ..strokeWidth = 1.5;
        for (double y = h * 0.32; y < h * 0.72; y += 8) {
          canvas.drawLine(Offset(w * 0.5, y), Offset(w * 0.5, y + 4), dashPaint);
        }

        // Stamp accent
        canvas.drawCircle(Offset(w * 0.68, h * 0.40), 9, accentPaint);

      case EmptyIllustrationType.chats:
        // Dialogue bubbles
        final bubble1 = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.28, w * 0.48, h * 0.35),
          const Radius.circular(14),
        );
        final bubble2 = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.40, h * 0.48, w * 0.45, h * 0.32),
          const Radius.circular(14),
        );

        canvas.drawRRect(
          bubble1,
          Paint()
            ..color = primaryColor.withAlpha(35)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(bubble1, primaryLine);

        canvas.drawRRect(
          bubble2,
          Paint()
            ..color = primaryColor.withAlpha(45)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(bubble2, primaryLine);

        // Chat indicator dots in bubble 2
        canvas.drawCircle(Offset(w * 0.52, h * 0.64), 3, accentPaint);
        canvas.drawCircle(Offset(w * 0.62, h * 0.64), 3, accentPaint);
        canvas.drawCircle(Offset(w * 0.72, h * 0.64), 3, accentPaint);

      case EmptyIllustrationType.safety:
        // Shield & Safe Checkmark
        final shield = Path()
          ..moveTo(w * 0.5, h * 0.2)
          ..cubicTo(w * 0.72, h * 0.2, w * 0.8, h * 0.32, w * 0.8, h * 0.52)
          ..cubicTo(w * 0.8, h * 0.75, w * 0.5, h * 0.88, w * 0.5, h * 0.88)
          ..cubicTo(w * 0.5, h * 0.88, w * 0.2, h * 0.75, w * 0.2, h * 0.52)
          ..cubicTo(w * 0.2, h * 0.32, w * 0.28, h * 0.2, w * 0.5, h * 0.2)
          ..close();

        canvas.drawPath(
          shield,
          Paint()
            ..color = primaryColor.withAlpha(30)
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(shield, primaryLine);

        // Checkmark inside shield
        final check = Path()
          ..moveTo(w * 0.38, h * 0.54)
          ..lineTo(w * 0.47, h * 0.63)
          ..lineTo(w * 0.64, h * 0.44);
        canvas.drawPath(
          check,
          Paint()
            ..color = accentColor
            ..strokeWidth = 3.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

      case EmptyIllustrationType.generic:
        // Compass disc
        canvas.drawCircle(
          Offset(w * 0.5, h * 0.5),
          h * 0.35,
          Paint()
            ..color = primaryColor.withAlpha(25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), h * 0.35, primaryLine);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), 5, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BrandIllustrationPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
