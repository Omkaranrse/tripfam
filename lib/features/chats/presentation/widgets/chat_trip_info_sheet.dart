import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../trips/data/trip_repository.dart';
import '../../../trips/domain/trip.dart';
import 'chat_moderation_dialogs.dart';

class ChatTripInfoSheet extends ConsumerWidget {
  const ChatTripInfoSheet({
    required this.tripId,
    required this.tripTitle,
    this.destination,
    super.key,
  });

  final String tripId;
  final String tripTitle;
  final String? destination;

  static void show(
    BuildContext context, {
    required String tripId,
    required String tripTitle,
    String? destination,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatTripInfoSheet(
        tripId: tripId,
        tripTitle: tripTitle,
        destination: destination,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tripAsync = ref.watch(tripDetailProvider(tripId));

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tripTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (destination != null)
                            Text(
                              destination!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(160),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: tripAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator.adaptive()),
                  error: (e, _) => Center(
                    child: Text('Unable to load trip details: $e'),
                  ),
                  data: (trip) => _buildTripContent(context, trip, scrollController),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripContent(
    BuildContext context,
    Trip? trip,
    ScrollController scrollController,
  ) {
    final theme = Theme.of(context);

    if (trip == null) {
      return const Center(child: Text('Trip information not available'));
    }

    final datesStr =
        '${trip.startDate.day}/${trip.startDate.month}/${trip.startDate.year} – ${trip.endDate.day}/${trip.endDate.month}/${trip.endDate.year}';
    final meetingPoint = trip.meetingPoint.isNotEmpty
        ? trip.meetingPoint
        : 'Confirmed by host prior to departure';

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Dates & Meeting Point Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outline.withAlpha(40),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        datesStr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meeting Point',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                          Text(
                            meetingPoint,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Trip Members Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trip Members (${trip.confirmedMembersCount}/${trip.maxMembers})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Intro calls completed',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Host Row
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withAlpha(40),
            child: Text(
              (trip.hostDisplayName.isNotEmpty
                      ? trip.hostDisplayName[0]
                      : 'H')
                  .toUpperCase(),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  trip.hostDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HOST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trip.hostIsVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Color(0xFF2E7D32),
                ),
              ],
            ],
          ),
          subtitle: const Text('Trip organizer'),
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        // Moderation Actions
        Text(
          'Safety & Moderation',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag_outlined, color: Colors.orange),
          title: const Text('Report Trip or User'),
          subtitle: const Text('Flag policy violations or safety concerns'),
          onTap: () {
            Navigator.pop(context);
            ChatReportDialog.show(
              context,
              reportedUserId: trip.hostId,
              reportedUserName: trip.hostDisplayName,
              tripId: trip.id,
            );
          },
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.block_outlined, color: Colors.red),
          title: const Text('Block User'),
          subtitle: const Text('Prevent all interaction and hide messages'),
          onTap: () {
            Navigator.pop(context);
            ChatBlockConfirmDialog.show(
              context,
              userId: trip.hostId,
              userName: trip.hostDisplayName,
            );
          },
        ),
      ],
    );
  }
}
