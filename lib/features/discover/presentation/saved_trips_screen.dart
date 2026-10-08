import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../trips/data/saved_trip_repository.dart';
import '../../trips/domain/trip.dart';
import 'controllers/deck_controller.dart';

class SavedTripsScreen extends ConsumerStatefulWidget {
  const SavedTripsScreen({super.key});

  @override
  ConsumerState<SavedTripsScreen> createState() => _SavedTripsScreenState();
}

class _SavedTripsScreenState extends ConsumerState<SavedTripsScreen> {
  Future<void> _handleUnsave(Trip trip) async {
    final repo = ref.read(savedTripRepositoryProvider);
    await repo.unsaveTrip(trip.id);
    ref.invalidate(savedTripsProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${trip.destination}" from saved trips'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFFC6E062), // Lime accent
          onPressed: () async {
            await repo.saveTrip(trip.id);
            ref.invalidate(savedTripsProvider);
          },
        ),
      ),
    );
  }

  String _resolveTripStatus(Trip trip) {
    final now = DateTime.now();
    if (trip.endDate.isBefore(now)) return 'Past';
    if (trip.availablePlaces <= 0) return 'Full';
    return 'Open';
  }

  Color _resolveStatusColor(BuildContext context, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'Open':
        return isDark ? const Color(0xFF81C784) : const Color(0xFF286544);
      case 'Full':
        return isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
      case 'Past':
      default:
        return isDark ? Colors.white54 : Colors.black45;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final savedTripsAsync = ref.watch(savedTripsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Trips'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: savedTripsAsync.when(
        loading: () => const LoadingView(message: 'Loading saved trips...'),
        error: (error, _) => ErrorView(
          title: 'Unable to load saved trips',
          message: error.toString(),
          onRetry: () => ref.invalidate(savedTripsProvider),
        ),
        data: (trips) {
          if (trips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bookmark_border_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    Text(
                      'No saved trips yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      'Swipe left on cards in Discover to save trips for later.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.explore_rounded, size: 18),
                      label: const Text('Explore trips'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s16),
            itemCount: trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (context, index) {
              final trip = trips[index];
              final status = _resolveTripStatus(trip);
              final statusColor = _resolveStatusColor(context, status);

              return Dismissible(
                key: ValueKey('saved_${trip.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: AppRadius.border20,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_remove_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Unsave',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) => _handleUnsave(trip),
                child: AppCard(
                  variant: AppCardVariant.elevated,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  onTap: () => context.push('/trip/${trip.id}'),
                  child: Row(
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: AppRadius.border12,
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: DestinationImage(
                            tripId: trip.id,
                            destination: trip.destination,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    trip.destination,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color: statusColor.withAlpha(70),
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${trip.startDate.day}/${trip.startDate.month} – ${trip.endDate.day}/${trip.endDate.month} (${trip.durationDays}d)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(160),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.group_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${trip.confirmedMembersCount}/${trip.maxMembers} members',
                                  style: theme.textTheme.bodySmall,
                                ),
                                if (trip.budget != null) ...[
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.payments_outlined,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '\$${trip.budget!.round()}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
