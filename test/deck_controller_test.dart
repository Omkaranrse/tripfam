import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tripfam/core/providers/app_providers.dart';
import 'package:tripfam/features/account/data/auth_repository.dart';
import 'package:tripfam/features/chats/data/chat_repository.dart';
import 'package:tripfam/features/discover/domain/deck_config.dart';
import 'package:tripfam/features/discover/presentation/controllers/deck_controller.dart';
import 'package:tripfam/features/trips/data/saved_trip_repository.dart';
import 'package:tripfam/features/trips/data/trip_repository.dart';
import 'package:tripfam/features/trips/domain/trip.dart';
import 'package:tripfam/features/trips/domain/trip_filter.dart';

class MockTripRepository implements TripRepository {
  MockTripRepository(this.trips);

  final List<Trip> trips;

  @override
  Future<List<Trip>> getDiscoverTrips({TripFilter? filter, int limit = 20, int offset = 0}) async {
    return trips;
  }

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

class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this.currentUser);

  @override
  final User? currentUser;

  @override
  Session? get currentSession => null;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Future<bool> signInWithGoogle() async => true;

  @override
  Future<void> signInWithOtp(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResponse> verifyOtp(String email, String token) async =>
      AuthResponse(session: null, user: currentUser);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late MockSavedTripRepository mockSavedRepo;

  final now = DateTime.now();

  Trip makeTrip({
    required String id,
    String hostId = 'host_other',
    String destination = 'Goa',
    int maxMembers = 4,
    int confirmedMembers = 1,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Trip(
      id: id,
      hostId: hostId,
      destination: destination,
      startDate: startDate ?? now.add(const Duration(days: 10)),
      endDate: endDate ?? now.add(const Duration(days: 15)),
      maxMembers: maxMembers,
      confirmedMembersCount: confirmedMembers,
      description: 'Trip to $destination',
    );
  }

  User makeTestUser(String id) => User(
        id: id,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-01',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    mockSavedRepo = MockSavedTripRepository();
  });

  group('DeckController Unit Tests', () {
    test('Loads initial batch and filters exclusions properly', () async {
      final tripList = [
        makeTrip(id: 'trip_valid_1', destination: 'Manali'),
        makeTrip(id: 'trip_valid_2', destination: 'Ladakh'),
        makeTrip(id: 'trip_own', hostId: 'user_current'), // Exclusion 1: own trip
        makeTrip(id: 'trip_full', maxMembers: 2, confirmedMembers: 2), // Exclusion 4: full
        makeTrip(
          id: 'trip_past',
          startDate: now.subtract(const Duration(days: 10)),
          endDate: now.subtract(const Duration(days: 5)),
        ), // Exclusion 5: past
        makeTrip(id: 'trip_blocked', hostId: 'user_blocked'), // Exclusion 6: blocked user
      ];

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripRepositoryProvider.overrideWithValue(MockTripRepository(tripList)),
          savedTripRepositoryProvider.overrideWithValue(mockSavedRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(makeTestUser('user_current')),
          ),
          blockedUsersProvider.overrideWith((ref) => Future.value({'user_blocked'})),
        ],
      );

      final controller = container.read(deckControllerProvider.notifier);
      await controller.loadInitial();

      final state = container.read(deckControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.trips.length, 2);
      expect(state.trips.map((t) => t.id).toList(), ['trip_valid_1', 'trip_valid_2']);
      expect(state.currentTrip?.id, 'trip_valid_1');
    });

    test('Swiping saves or skips according to kSaveDirection', () async {
      final tripList = [
        makeTrip(id: 'trip_1', destination: 'Udaipur'),
        makeTrip(id: 'trip_2', destination: 'Rishikesh'),
      ];

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripRepositoryProvider.overrideWithValue(MockTripRepository(tripList)),
          savedTripRepositoryProvider.overrideWithValue(mockSavedRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(makeTestUser('user_current')),
          ),
          blockedUsersProvider.overrideWith((ref) => Future.value({})),
        ],
      );

      final controller = container.read(deckControllerProvider.notifier);
      await controller.loadInitial();

      // Swipe in save direction (kSaveDirection is left by default)
      final savedTrip = await controller.swipe(kSaveDirection);
      expect(savedTrip?.id, 'trip_1');
      expect(container.read(deckControllerProvider).savedTripIds.contains('trip_1'), isTrue);
      expect(container.read(deckControllerProvider).currentIndex, 1);
      expect(container.read(deckControllerProvider).currentTrip?.id, 'trip_2');

      // Swipe opposite direction (dismiss)
      const oppositeDirection = kSaveDirection == SwipeDirection.left
          ? SwipeDirection.right
          : SwipeDirection.left;
      final dismissedTrip = await controller.swipe(oppositeDirection);
      expect(dismissedTrip?.id, 'trip_2');
      expect(container.read(deckControllerProvider).dismissedTripIds.contains('trip_2'), isTrue);
      expect(container.read(deckControllerProvider).remainingTrips.isEmpty, isTrue);
    });

    test('Undo reverses previous swipe action and restores card to deck', () async {
      final tripList = [
        makeTrip(id: 'trip_1', destination: 'Kerala'),
      ];

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tripRepositoryProvider.overrideWithValue(MockTripRepository(tripList)),
          savedTripRepositoryProvider.overrideWithValue(mockSavedRepo),
          authRepositoryProvider.overrideWithValue(
            MockAuthRepository(makeTestUser('user_current')),
          ),
          blockedUsersProvider.overrideWith((ref) => Future.value({})),
        ],
      );

      final controller = container.read(deckControllerProvider.notifier);
      await controller.loadInitial();

      // Save trip_1
      await controller.swipe(kSaveDirection);
      expect(container.read(deckControllerProvider).currentIndex, 1);
      expect(container.read(deckControllerProvider).canUndo, isTrue);

      // Undo
      final restored = await controller.undo();
      expect(restored?.id, 'trip_1');
      expect(container.read(deckControllerProvider).currentIndex, 0);
      expect(container.read(deckControllerProvider).savedTripIds.contains('trip_1'), isFalse);
      expect(container.read(deckControllerProvider).currentTrip?.id, 'trip_1');
    });
  });
}
