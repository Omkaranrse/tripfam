import 'dart:ui';

import 'package:flutter/material.dart';

import '../demo/demo_data.dart';
import '../theme/app_tokens.dart';

class DestinationImage extends StatelessWidget {
  const DestinationImage({
    required this.tripId,
    required this.destination,
    super.key,
    this.aspectRatio = 16 / 10,
    this.borderRadius = AppRadius.border12,
    this.fit = BoxFit.cover,
    this.height,
    this.width,
  });

  final String tripId;
  final String destination;
  final double? aspectRatio;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final double? height;
  final double? width;

  static String getImageUrlForDestination(String destination, {String? tripId}) {
    final idx = tripId != null ? tripId.hashCode.abs() : 0;
    return DemoImages.forDestination(destination, index: idx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = getImageUrlForDestination(destination, tripId: tripId);

    Widget imageWidget = Image.network(
      imageUrl,
      fit: fit,
      width: width ?? double.infinity,
      height: height,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        // Shimmer-style placeholder that fades in the image
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildShimmerPlaceholder(
            theme,
            width: width ?? double.infinity,
            height: height,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildBlurredPlaceholder(
          theme,
          width: width ?? double.infinity,
          height: height,
        );
      },
    );

    Widget inner = aspectRatio != null
        ? AspectRatio(aspectRatio: aspectRatio!, child: imageWidget)
        : imageWidget;

    Widget content = SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ClipRRect(borderRadius: borderRadius, child: inner),
    );

    return Hero(tag: 'trip-image-$tripId', child: content);
  }

  Widget _buildShimmerPlaceholder(
    ThemeData theme, {
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHighest.withAlpha(140),
            theme.colorScheme.surfaceContainerHighest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          size: 32,
          color: theme.colorScheme.primary.withAlpha(60),
        ),
      ),
    );
  }

  Widget _buildBlurredPlaceholder(
    ThemeData theme, {
    double? width,
    double? height,
  }) {
    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Stack(
        fit: (height != null && height.isFinite)
            ? StackFit.expand
            : StackFit.loose,
        children: [
          // Blurred background pattern
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(color: theme.colorScheme.primary.withAlpha(25)),
            ),
          ),
          Center(
            child: Icon(
              Icons.landscape_rounded,
              size: 36,
              color: theme.colorScheme.primary.withAlpha(80),
            ),
          ),
        ],
      ),
    );
  }
}
