import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../trips/domain/trip.dart';
import '../../domain/deck_config.dart';
import 'deck_card_clipper.dart';

class SwipeableDeck extends StatefulWidget {
  const SwipeableDeck({
    required this.trips,
    required this.onSwipe,
    required this.onTapTrip,
    super.key,
    this.deckWidth = 380.0,
    this.deckHeight = 330.0,
  });

  final List<Trip> trips;
  final Future<void> Function(SwipeDirection direction) onSwipe;
  final void Function(Trip trip) onTapTrip;
  final double deckWidth;
  final double deckHeight;

  @override
  State<SwipeableDeck> createState() => SwipeableDeckState();
}

class SwipeableDeckState extends State<SwipeableDeck>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnimation;

  Offset _dragOffset = Offset.zero;
  bool _hasCrossedThreshold = false;
  bool _isAnimatingCommit = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_animController);
    _animController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant SwipeableDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Preload next 2 images
    if (widget.trips.length > 1) {
      _precacheImages();
    }
  }

  void _precacheImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (var i = 1; i < math.min(3, widget.trips.length); i++) {
        final trip = widget.trips[i];
        final imageUrl = DestinationImage.getImageUrlForDestination(
          trip.destination,
          tripId: trip.id,
        );
        precacheImage(
          NetworkImage(imageUrl),
          context,
          onError: (exception, stackTrace) {},
        );
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Programmatic swipe action for buttons and keyboard navigation
  void triggerSwipe(SwipeDirection direction) {
    if (_isAnimatingCommit || widget.trips.isEmpty) return;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    _isAnimatingCommit = true;
    HapticFeedback.lightImpact();

    if (disableAnimations) {
      widget.onSwipe(direction).then((_) {
        if (mounted) {
          setState(() {
            _dragOffset = Offset.zero;
            _isAnimatingCommit = false;
          });
        }
      });
      return;
    }

    final targetX = direction == SwipeDirection.right
        ? widget.deckWidth + 140.0
        : -(widget.deckWidth + 140.0);

    _offsetAnimation =
        Tween<Offset>(
          begin: _dragOffset,
          end: Offset(targetX, _dragOffset.dy),
        ).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _animController.forward(from: 0.0).then((_) {
      widget.onSwipe(direction).then((_) {
        if (mounted) {
          _animController.reset();
          setState(() {
            _dragOffset = Offset.zero;
            _isAnimatingCommit = false;
            _hasCrossedThreshold = false;
          });
        }
      });
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimatingCommit || widget.trips.isEmpty) return;
    _animController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingCommit || widget.trips.isEmpty) return;

    setState(() {
      _dragOffset += details.delta;

      final threshold35 = widget.deckWidth * 0.35;
      final isOverThreshold = _dragOffset.dx.abs() > threshold35;

      // Haptic triggers once on boundary crossing
      if (isOverThreshold && !_hasCrossedThreshold) {
        HapticFeedback.lightImpact();
        _hasCrossedThreshold = true;
      } else if (!isOverThreshold && _hasCrossedThreshold) {
        _hasCrossedThreshold = false;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimatingCommit || widget.trips.isEmpty) return;

    final threshold35 = widget.deckWidth * 0.35;
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final isCommittedByDrag = _dragOffset.dx.abs() > threshold35;
    final isCommittedByFling = velocityX.abs() > 700.0;

    if (isCommittedByDrag || isCommittedByFling) {
      final direction = (_dragOffset.dx > 0 || velocityX > 700.0)
          ? SwipeDirection.right
          : SwipeDirection.left;
      triggerSwipe(direction);
    } else {
      // Spring back to center
      _hasCrossedThreshold = false;
      _offsetAnimation = Tween<Offset>(begin: _dragOffset, end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _animController,
              curve: AppMotion.gentleSpring,
            ),
          );
      _animController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() => _dragOffset = Offset.zero);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trips.isEmpty) {
      return const SizedBox.shrink();
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final topTrip = widget.trips.first;

    // Maximum 3 cards in the widget tree
    final visibleTrips = widget.trips.take(3).toList();

    return Semantics(
      label: 'Trip ${topTrip.destination}, ${topTrip.durationDays} days',
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Skip trip'): () => triggerSwipe(
          kSaveDirection == SwipeDirection.left
              ? SwipeDirection.right
              : SwipeDirection.left,
        ),
        const CustomSemanticsAction(label: 'Save trip'): () =>
            triggerSwipe(kSaveDirection),
      },
      child: Center(
        child: SizedBox(
          width: widget.deckWidth,
          height: widget.deckHeight + 36.0,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // Bottom stacked cards (indices 2 and 1)
              for (var i = visibleTrips.length - 1; i >= 1; i--)
                _buildStackedCard(
                  trip: visibleTrips[i],
                  stackIndex: i,
                  disableAnimations: disableAnimations,
                ),

              // Top interactive card (index 0)
              _buildTopCard(
                trip: topTrip,
                disableAnimations: disableAnimations,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStackedCard({
    required Trip trip,
    required int stackIndex,
    required bool disableAnimations,
  }) {
    // Physical Cascading Peek:
    // stackIndex 1: scale 0.94, offset 13px downward peek
    // stackIndex 2: scale 0.88, offset 25px downward peek
    final baseScale = stackIndex == 1 ? 0.94 : 0.88;
    final baseOffset = stackIndex == 1 ? 13.0 : 25.0;

    // Interactive drag progress (when user drags the top card)
    final dragProgress = disableAnimations
        ? 0.0
        : (_dragOffset.dx.abs() / (widget.deckWidth * 0.45)).clamp(0.0, 1.0);

    // Dynamic animation during drag or commit dismiss
    final animProgress = _isAnimatingCommit && !disableAnimations
        ? _animController.value
        : dragProgress;

    // Target positions when front card is dismissed:
    // card 1 ascends to front (scale 1.0, offset 0.0)
    // card 2 ascends to card 1 (scale 0.94, offset 13.0)
    final targetScale = stackIndex == 1 ? 1.0 : 0.94;
    final targetOffset = stackIndex == 1 ? 0.0 : 13.0;

    final dynamicScale =
        baseScale + ((targetScale - baseScale) * animProgress);
    final dynamicOffset =
        baseOffset + ((targetOffset - baseOffset) * animProgress);

    // Layered shadow opacity: card behind is subtly shaded by card in front
    final baseShade = stackIndex == 1 ? 40 : 75;
    final targetShade = stackIndex == 1 ? 0 : 40;
    final dynamicShade =
        (baseShade + ((targetShade - baseShade) * animProgress)).round();

    return Positioned(
      top: dynamicOffset,
      child: Transform.scale(
        scale: dynamicScale,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(stackIndex == 1 ? 55 : 40),
                blurRadius: 18,
                spreadRadius: -2,
                offset: Offset(0, stackIndex == 1 ? 8 : 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Opacity(
                opacity: stackIndex == 1 ? 0.96 : 0.86,
                child: _buildCardContent(trip: trip, isInteractive: false),
              ),
              if (dynamicShade > 0)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.r28),
                      color: Colors.black.withAlpha(dynamicShade),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard({required Trip trip, required bool disableAnimations}) {
    final currentOffset = _isAnimatingCommit
        ? _offsetAnimation.value
        : _dragOffset;

    // Up to 12 degrees rotation proportional to horizontal drag
    const maxRadians = 12.0 * (math.pi / 180.0);
    final dragFraction = (currentOffset.dx / (widget.deckWidth * 0.5)).clamp(
      -1.0,
      1.0,
    );
    final rotation = disableAnimations ? 0.0 : dragFraction * maxRadians;

    final threshold15 = widget.deckWidth * 0.15;
    final threshold35 = widget.deckWidth * 0.35;

    // Overlay badge opacity
    double overlayOpacity = 0.0;
    SwipeDirection? activeDirection;

    if (currentOffset.dx.abs() > threshold15) {
      activeDirection = currentOffset.dx > 0
          ? SwipeDirection.right
          : SwipeDirection.left;
      overlayOpacity =
          ((currentOffset.dx.abs() - threshold15) / (threshold35 - threshold15))
              .clamp(0.0, 1.0);
    }

    Widget card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onTap: () => widget.onTapTrip(trip),
      child: Stack(
        children: [
          _buildCardContent(trip: trip, isInteractive: true),

          // Overlay Badge ("SAVED" or "SKIP" according to kSaveDirection)
          if (activeDirection != null && overlayOpacity > 0.0)
            Positioned(
              top: 28,
              left: activeDirection == SwipeDirection.right ? 24 : null,
              right: activeDirection == SwipeDirection.left ? 24 : null,
              child: Opacity(
                opacity: overlayOpacity,
                child: _buildOverlayBadge(activeDirection),
              ),
            ),
        ],
      ),
    );

    if (disableAnimations) {
      if (_isAnimatingCommit) {
        card = FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_animController),
          child: card,
        );
      }
      return Positioned(top: 0, child: card);
    }

    return Positioned(
      top: 0,
      child: Transform.translate(
        offset: currentOffset,
        child: Transform.rotate(
          angle: rotation,
          alignment: Alignment.bottomCenter,
          child: card,
        ),
      ),
    );
  }

  Widget _buildOverlayBadge(SwipeDirection direction) {
    final isSave = direction.isSave;
    final label = direction.overlayLabel;

    final color = isSave
        ? const Color(0xFFC6E062) // Lime accent
        : const Color(0xFFFF8A65); // Coral / Amber accent

    final textColor = isSave ? const Color(0xFF132219) : Colors.white;

    return Transform.rotate(
      angle: direction == SwipeDirection.right ? 0.15 : -0.15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(235),
          borderRadius: AppRadius.border16,
          border: Border.all(color: Colors.white.withAlpha(180), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSave ? Icons.bookmark_rounded : Icons.close_rounded,
              size: 20,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent({required Trip trip, required bool isInteractive}) {
    return Container(
      width: widget.deckWidth,
      height: widget.deckHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.r28),
        boxShadow: isInteractive
            ? AppShadows.floating(context)
            : AppShadows.elevated(context),
      ),
      child: ClipPath(
        clipper: const DeckCardClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo Image (Hero is built inside DestinationImage)
            DestinationImage(
              tripId: trip.id,
              destination: trip.destination,
              aspectRatio: null,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            ),

            // Subtle gradient scrims for contrast
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(70),
                      Colors.transparent,
                      Colors.black.withAlpha(180),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Top-left: Destination name with pin icon
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Align(
                alignment: Alignment.topLeft,
                child: GlassContainer(
                  borderRadius: AppRadius.borderPill,
                  blur: 14.0,
                  tintColor: Colors.black.withAlpha(90),
                  borderColor: Colors.white.withAlpha(60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Color(0xFFC6E062),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          trip.destination,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom overlay: Info chips (dates, duration, members x/max) & title
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trip.description.isNotEmpty
                        ? trip.description
                        : 'Explore ${trip.destination} with fellow travel mates.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Glass chips row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      InfoChip(
                        variant: InfoChipVariant.glass,
                        icon: Icons.calendar_today_rounded,
                        label:
                            '${trip.startDate.day}/${trip.startDate.month} – ${trip.endDate.day}/${trip.endDate.month}',
                      ),
                      InfoChip(
                        variant: InfoChipVariant.glass,
                        icon: Icons.group_rounded,
                        label:
                            '${trip.confirmedMembersCount}/${trip.maxMembers} members',
                      ),
                      if (trip.budget != null)
                        InfoChip(
                          variant: InfoChipVariant.glass,
                          icon: Icons.payments_outlined,
                          label: '\$${trip.budget!.round()}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
