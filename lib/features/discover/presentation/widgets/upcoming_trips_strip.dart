import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../trips/domain/trip.dart';

class UpcomingTripsStrip extends StatelessWidget {
  const UpcomingTripsStrip({
    required this.trips,
    required this.onTapTrip,
    super.key,
  });

  final List<Trip> trips;
  final void Function(Trip trip) onTapTrip;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Display at most 4 upcoming trips within the safe zone
    final stripTrips = trips.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              const maxCardWidth = 84.0;
              const spacing = 10.0;
              final totalCards = stripTrips.length;
              final useFixedCards =
                  (availableWidth / totalCards) > (maxCardWidth + spacing);

              return Row(
                mainAxisAlignment: useFixedCards
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.spaceBetween,
                children: List.generate(totalCards, (index) {
                  final trip = stripTrips[index];
                  final card = _buildCard(
                    context: context,
                    trip: trip,
                    index: index,
                    isDark: isDark,
                    theme: theme,
                  );

                  if (useFixedCards) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: index < totalCards - 1 ? spacing : 0,
                      ),
                      child: SizedBox(
                        width: maxCardWidth,
                        height: maxCardWidth * 1.05,
                        child: card,
                      ),
                    );
                  }

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: index < totalCards - 1 ? spacing : 0,
                      ),
                      child: AspectRatio(aspectRatio: 0.95, child: card),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required Trip trip,
    required int index,
    required bool isDark,
    required ThemeData theme,
  }) {
    // Gentle alternating tilt (-0.03 to +0.03 rad)
    final tiltAngle = (index % 2 == 0) ? -0.03 : 0.03;

    return Tooltip(
      message: 'Jump to ${trip.destination}',
      child: InkWell(
        onTap: () => onTapTrip(trip),
        borderRadius: AppRadius.border12,
        child: Transform.rotate(
          angle: tiltAngle,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppRadius.border12,
              boxShadow: AppShadows.subtle(context),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(35)
                    : theme.colorScheme.outline.withAlpha(70),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.border12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DestinationImage(
                    tripId: trip.id,
                    destination: trip.destination,
                    aspectRatio: null,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(190),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Text(
                      trip.destination,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
