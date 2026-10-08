import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'destination_image.dart';
import 'glass_container.dart';
import 'info_chip.dart';

class FeaturedTripCard extends StatefulWidget {
  const FeaturedTripCard({
    required this.tripId,
    required this.destination,
    required this.title,
    required this.daysLabel,
    required this.paceLabel,
    required this.membersLabel,
    super.key,
    this.scrollOffset = 0.0,
    this.onTap,
    this.ctaLabel = 'View Departure',
    this.onCtaPressed,
  });

  final String tripId;
  final String destination;
  final String title;
  final String daysLabel;
  final String paceLabel;
  final String membersLabel;
  final double scrollOffset;
  final VoidCallback? onTap;
  final String ctaLabel;
  final VoidCallback? onCtaPressed;

  @override
  State<FeaturedTripCard> createState() => _FeaturedTripCardState();
}

class _FeaturedTripCardState extends State<FeaturedTripCard> {
  bool _isPressed = false;
  bool _isFavorited = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final parallaxOffset = disableAnimations
        ? 0.0
        : (widget.scrollOffset * 0.10).clamp(-16.0, 16.0);

    return AnimatedScale(
      scale: _isPressed && !disableAnimations ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.border28,
          boxShadow: AppShadows.floating(context),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.border28,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  // Full-bleed photo with subtle parallax
                  Transform.translate(
                    offset: Offset(0, parallaxOffset),
                    child: DestinationImage(
                      tripId: widget.tripId,
                      destination: widget.destination,
                      aspectRatio: 16 / 11,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),

                  // Dark bottom scrim for text legibility (contrast >= 4.5:1)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(40),
                            Colors.black.withAlpha(220),
                          ],
                          stops: const [0.3, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Circular Glass Favorite Button on photo header
                  Positioned(
                    top: AppSpacing.s12,
                    right: AppSpacing.s12,
                    child: GlassIconButton(
                      icon: _isFavorited
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: _isFavorited ? Colors.redAccent : Colors.white,
                      tooltip: _isFavorited
                          ? 'Remove from favorites'
                          : 'Save to favorites',
                      onPressed: () {
                        setState(() => _isFavorited = !_isFavorited);
                      },
                    ),
                  ),

                  // Overlay Content
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Uppercase destination badge
                        GlassContainer(
                          borderRadius: AppRadius.borderPill,
                          blur: 12.0,
                          tintColor: Colors.white.withAlpha(40),
                          borderColor: Colors.white.withAlpha(60),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          child: Text(
                            widget.destination.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),

                        // Display Title
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        // Info Chips: duration, pace, members x/max (Glass over photo)
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InfoChip(
                              variant: InfoChipVariant.glass,
                              icon: Icons.wb_sunny_outlined,
                              label: widget.daysLabel,
                            ),
                            InfoChip(
                              variant: InfoChipVariant.glass,
                              icon: Icons.directions_walk_rounded,
                              label: widget.paceLabel,
                            ),
                            InfoChip(
                              variant: InfoChipVariant.glass,
                              icon: Icons.group_outlined,
                              label: widget.membersLabel,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Primary Action Pill Button
                        PrimaryButton(
                          label: widget.ctaLabel,
                          onPressed: widget.onCtaPressed ?? widget.onTap,
                          isFullWidth: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
