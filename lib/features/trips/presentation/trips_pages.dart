import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/trip_preview_repository.dart';
import '../domain/trip_preview.dart';

class MyTripsPage extends ConsumerWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(upcomingTripsProvider);
    return trips.when(
      data: (items) => items.isEmpty
          ? ListView(
              children: [
                const _PageHeading(
                  title: 'Your trips',
                  subtitle:
                      'Keep your travel plans and companions in one place.',
                ),
                const SizedBox(height: 24),
                const _EmptyTripsPanel(),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/discover'),
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Explore trips'),
                  ),
                ),
              ],
            )
          : _TripGrid(trips: items, title: 'Your trips'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const _SafeLoadError(),
    );
  }
}

class DiscoverTripsPage extends ConsumerWidget {
  const DiscoverTripsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(discoverTripsProvider);
    return trips.when(
      data: (items) => _TripGrid(
        trips: items,
        title: 'Discover trips',
        subtitle: 'Meet your fellow travellers before you set off.',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const _SafeLoadError(),
    );
  }
}

class _TripGrid extends StatelessWidget {
  const _TripGrid({required this.trips, required this.title, this.subtitle});

  final List<TripPreview> trips;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900
            ? 3
            : width >= 600
            ? 2
            : 1;
        const gap = 16.0;
        final cardWidth = (width - (gap * (columns - 1))) / columns;

        return ListView(
          children: [
            _PageHeading(title: title, subtitle: subtitle),
            const SizedBox(height: 24),
            if (trips.isEmpty)
              const _EmptyTripsPanel()
            else
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final trip in trips)
                    SizedBox(
                      width: cardWidth,
                      child: _TripCard(trip: trip),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});

  final TripPreview trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.destination,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(trip.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(trip.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _TripFact(
                  icon: Icons.calendar_today_outlined,
                  label: _dateLabel(trip.departureDate),
                ),
                _TripFact(
                  icon: Icons.schedule_outlined,
                  label: '${trip.durationDays} days',
                ),
                _TripFact(
                  icon: Icons.group_outlined,
                  label:
                      '${trip.travellerCount} travelling · ${trip.availablePlaces} places',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _TripFact extends StatelessWidget {
  const _TripFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.secondary),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: textTheme.bodyLarge),
        ],
      ],
    );
  }
}

class _EmptyTripsPanel extends StatelessWidget {
  const _EmptyTripsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.luggage_outlined, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('No trips yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Once you join a trip, its plans and travel companions will show up here.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SafeLoadError extends StatelessWidget {
  const _SafeLoadError();

  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Trips could not be loaded right now. Please try again later.'),
  );
}
