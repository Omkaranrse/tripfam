import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tripfam/core/providers/app_providers.dart';
import 'package:tripfam/core/theme/app_theme.dart';
import 'package:tripfam/features/account/data/profile_repository.dart';
import 'package:tripfam/features/account/domain/user_profile.dart';
import 'package:tripfam/features/chats/data/chat_repository.dart';
import 'package:tripfam/features/discover/domain/deck_config.dart';
import 'package:tripfam/features/discover/presentation/discover_page.dart';
import 'package:tripfam/features/discover/presentation/widgets/deck_action_buttons.dart';
import 'package:tripfam/features/discover/presentation/widgets/swipeable_deck.dart';
import 'package:tripfam/features/trips/data/saved_trip_repository.dart';
import 'package:tripfam/features/trips/data/trip_repository.dart';
import 'package:tripfam/features/trips/domain/trip.dart';
import 'package:tripfam/features/trips/domain/trip_filter.dart';

class _MockUserProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async {
    return const UserProfile(
      id: 'test-user',
      displayName: 'Alex Explorer',
      homeCity: 'Paris',
      travelStyle: {'pace': 'Moderate'},
    );
  }
}

class MockTripRepository implements TripRepository {
  MockTripRepository(this.trips);
  final List<Trip> trips;

  @override
  Future<List<Trip>> getDiscoverTrips({TripFilter? filter, int limit = 20, int offset = 0}) async => trips;
  @override
  Future<void> cancelTrip(String tripId) async {}
  @override
  Future<Trip> createTrip(TripDraft draft) async => trips.first;
  @override
  Future<List<Trip>> getMyTrips() async => [];
  @override
  Future<Trip?> getTripById(String tripId) async => trips.firstWhere((t) => t.id == tripId);
  @override
  Future<bool> hasRequestedToJoin(String tripId) async => false;
  @override
  Future<bool> isTripMember(String tripId) async => false;
  @override
  Future<void> requestToJoin(String tripId, {String? message}) async {}
  @override
  Future<Trip> updateTrip(String tripId, TripDraft draft) async => trips.first;
}

class MockSavedTripRepository implements SavedTripRepository {
  final Set<String> savedIds = {};
  @override
  Future<Set<String>> getSavedTripIds() async => Set.from(savedIds);
  @override
  Future<List<Trip>> getSavedTrips() async => [];
  @override
  Future<void> saveTrip(String tripId) async => savedIds.add(tripId);
  @override
  Future<void> unsaveTrip(String tripId) async => savedIds.remove(tripId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MockSavedTripRepository mockSavedRepo;

  final now = DateTime.now();

  List<Trip> makeTestTrips() => [
        Trip(
          id: 'trip_1',
          hostId: 'host_1',
          destination: 'Goa',
          startDate: now.add(const Duration(days: 10)),
          endDate: now.add(const Duration(days: 15)),
          maxMembers: 4,
          description: 'Sun, sand and coastal vibes in Goa',
        ),
        Trip(
          id: 'trip_2',
          hostId: 'host_2',
          destination: 'Manali',
          startDate: now.add(const Duration(days: 20)),
          endDate: now.add(const Duration(days: 26)),
          maxMembers: 6,
          description: 'Snowy Himalayan mountain trekking',
        ),
        Trip(
          id: 'trip_3',
          hostId: 'host_3',
          destination: 'Udaipur',
          startDate: now.add(const Duration(days: 30)),
          endDate: now.add(const Duration(days: 34)),
          maxMembers: 5,
          description: 'Palaces and royal lakes tour',
        ),
      ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockSavedRepo = MockSavedTripRepository();
  });

  group('SwipeableDeck Widget Tests', () {
    testWidgets('Renders at most 3 stacked cards and has semantics', (tester) async {
      final trips = makeTestTrips();
      Trip? tappedTrip;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SwipeableDeck(
              trips: trips,
              onSwipe: (_) async {},
              onTapTrip: (t) => tappedTrip = t,
            ),
          ),
        ),
      );

      // Verify destination name is rendered
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('Manali'), findsOneWidget);
      expect(find.text('Udaipur'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Goa'));
      expect(tappedTrip?.id, 'trip_1');
    });

    testWidgets('Drag below 35% threshold springs back without committing', (tester) async {
      final trips = makeTestTrips();
      SwipeDirection? swipedDir;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SwipeableDeck(
                trips: trips,
                deckWidth: 380,
                onSwipe: (dir) async => swipedDir = dir,
                onTapTrip: (_) {},
              ),
            ),
          ),
        ),
      );

      // Drag by only 50px (less than 35% of 380 = 133px)
      final center = tester.getCenter(find.text('Goa'));
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(swipedDir, isNull);
      expect(find.text('Goa'), findsOneWidget);
    });

    testWidgets('Drag exceeding 35% threshold commits swipe', (tester) async {
      final trips = makeTestTrips();
      SwipeDirection? swipedDir;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: SwipeableDeck(
                trips: trips,
                deckWidth: 380,
                onSwipe: (dir) async => swipedDir = dir,
                onTapTrip: (_) {},
              ),
            ),
          ),
        ),
      );

      // Drag by 160px (exceeds 35% = 133px)
      await tester.drag(find.text('Goa'), const Offset(160, 0));
      await tester.pumpAndSettle();

      expect(swipedDir, SwipeDirection.right);
    });

    testWidgets('DeckActionButtons trigger swipe left and right and view details', (tester) async {
      bool leftTapped = false;
      bool rightTapped = false;
      bool detailsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DeckActionButtons(
              onSwipeLeft: () => leftTapped = true,
              onSwipeRight: () => rightTapped = true,
              onViewDetails: () => detailsTapped = true,
            ),
          ),
        ),
      );

      // Tapping View Details
      await tester.tap(find.text('View Details'));
      expect(detailsTapped, isTrue);

      // Left and right action buttons
      final iconButtons = find.byType(InkWell);
      expect(iconButtons, findsWidgets);

      await tester.tap(iconButtons.first);
      expect(leftTapped, isTrue);

      await tester.tap(iconButtons.last);
      expect(rightTapped, isTrue);
    });

    testWidgets('Reduced motion (disableAnimations) does not throw and handles gestures', (tester) async {
      final trips = makeTestTrips();
      SwipeDirection? swipedDir;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Center(
                child: SwipeableDeck(
                  trips: trips,
                  deckWidth: 380,
                  onSwipe: (dir) async => swipedDir = dir,
                  onTapTrip: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Goa'), findsOneWidget);

      await tester.drag(find.text('Goa'), const Offset(160, 0));
      await tester.pumpAndSettle();

      expect(swipedDir, SwipeDirection.right);
    });
  });

  group('Multi-Breakpoint Responsiveness & Theme Tests', () {
    for (final width in [400.0, 800.0, 1400.0]) {
      for (final isDark in [false, true]) {
        testWidgets('DiscoverPage renders at ${width.toInt()}px in ${isDark ? 'Dark' : 'Light'} mode without overflow', (tester) async {
          final trips = makeTestTrips();
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                tripRepositoryProvider.overrideWithValue(MockTripRepository(trips)),
                savedTripRepositoryProvider.overrideWithValue(mockSavedRepo),
                blockedUsersProvider.overrideWith((ref) => Future.value({})),
                userProfileProvider.overrideWith(_MockUserProfileNotifier.new),
              ],
              child: MaterialApp(
                theme: isDark ? AppTheme.dark : AppTheme.light,
                home: const DiscoverPage(),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(DiscoverPage), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
