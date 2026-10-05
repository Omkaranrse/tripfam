import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip_preview.dart';

abstract interface class TripPreviewRepository {
  Future<List<TripPreview>> getDiscoverTrips();

  Future<List<TripPreview>> getUpcomingTrips();
}

class DemoTripPreviewRepository implements TripPreviewRepository {
  const DemoTripPreviewRepository();

  static final _discoverTrips = [
    TripPreview(
      destination: 'Lisbon, Portugal',
      title: 'A week between city and sea',
      summary: 'Local food, coastal walks, and an unhurried itinerary.',
      departureDate: DateTime(2026, 11, 14),
      durationDays: 7,
      travellerCount: 3,
      availablePlaces: 2,
    ),
    TripPreview(
      destination: 'Kyoto, Japan',
      title: 'Autumn in Kyoto',
      summary: 'Temples, neighborhood cafés, and a day trip to Nara.',
      departureDate: DateTime(2026, 11, 21),
      durationDays: 8,
      travellerCount: 2,
      availablePlaces: 3,
    ),
    TripPreview(
      destination: 'Medellín, Colombia',
      title: 'A slower side of Medellín',
      summary: 'Explore the city, then spend a few days in the mountains.',
      departureDate: DateTime(2026, 12, 3),
      durationDays: 9,
      travellerCount: 4,
      availablePlaces: 1,
    ),
  ];

  @override
  Future<List<TripPreview>> getDiscoverTrips() async => _discoverTrips;

  @override
  Future<List<TripPreview>> getUpcomingTrips() async => const [];
}

final tripPreviewRepositoryProvider = Provider<TripPreviewRepository>(
  (ref) => const DemoTripPreviewRepository(),
);

final discoverTripsProvider = FutureProvider<List<TripPreview>>(
  (ref) => ref.watch(tripPreviewRepositoryProvider).getDiscoverTrips(),
);

final upcomingTripsProvider = FutureProvider<List<TripPreview>>(
  (ref) => ref.watch(tripPreviewRepositoryProvider).getUpcomingTrips(),
);
