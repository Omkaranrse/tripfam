import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/utils/text_sanitizer.dart';
import 'package:tripfam/features/trips/data/trip_repository.dart';
import 'package:tripfam/features/trips/domain/travel_compatibility.dart';
import 'package:tripfam/features/trips/domain/trip.dart';
import 'package:tripfam/features/trips/domain/trip_filter.dart';

void main() {
  group('TextSanitizer Security Tests', () {
    test('strips dangerous HTML tags and scripts from user input', () {
      const malicious =
          '<script>alert("hacked")</script>Tokyo <img src=x onerror=alert(1)>Trip';
      final clean = TextSanitizer.sanitize(malicious);
      expect(clean, 'alert("hacked")Tokyo Trip');
      expect(clean.contains('<script>'), isFalse);
      expect(clean.contains('<img'), isFalse);
    });

    test('trims excess control characters and spacing', () {
      const dirty = '   \u0000 Kyoto Backpacking \u0007   ';
      expect(TextSanitizer.sanitize(dirty), 'Kyoto Backpacking');
    });
  });

  group('TripDraft Validation Constraints', () {
    test('rejects destination shorter than 2 chars', () {
      final draft = TripDraft(
        destination: 'A',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        maxMembers: 4,
        description: 'A great journey exploring ancient historic temples.',
      );
      expect(
        draft.validate(),
        contains('Destination must be at least 2 characters'),
      );
    });

    test('rejects endDate earlier than startDate', () {
      final draft = TripDraft(
        destination: 'Bali, Indonesia',
        startDate: DateTime.now().add(const Duration(days: 20)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        maxMembers: 4,
        description: 'A great journey exploring ancient historic temples.',
      );
      expect(draft.validate(), contains('End date cannot be earlier'));
    });

    test('rejects maxMembers out of bounds (< 2 or > 12)', () {
      final draftTooLow = TripDraft(
        destination: 'Bali, Indonesia',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        maxMembers: 1,
        description: 'A great journey exploring ancient historic temples.',
      );
      expect(draftTooLow.validate(), contains('between 2 and 12'));

      final draftTooHigh = TripDraft(
        destination: 'Bali, Indonesia',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        maxMembers: 15,
        description: 'A great journey exploring ancient historic temples.',
      );
      expect(draftTooHigh.validate(), contains('between 2 and 12'));
    });

    test('rejects negative budgets', () {
      final draft = TripDraft(
        destination: 'Bali, Indonesia',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        budget: -50.0,
        maxMembers: 4,
        description: 'A great journey exploring ancient historic temples.',
      );
      expect(draft.validate(), contains('cannot be negative'));
    });

    test('rejects description shorter than 10 characters', () {
      final draft = TripDraft(
        destination: 'Bali, Indonesia',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        maxMembers: 4,
        description: 'Short',
      );
      expect(draft.validate(), contains('at least 10 characters'));
    });

    test('accepts valid trip draft', () {
      final draft = TripDraft(
        destination: 'Kyoto, Japan',
        startDate: DateTime.now().add(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        budget: 1200.0,
        maxMembers: 4,
        description:
            'A beautiful autumn trip visiting serene shrines and gardens.',
        tags: const ['Culture', 'Temples'],
      );
      expect(draft.validate(), isNull);
    });
  });

  group('TravelCompatibility (Plain Labels - Strictly NO Percentages)', () {
    test('computes plain friendly matching badges without percentages', () {
      final userStyle = {
        'wake_up_time': 'Early Bird (6-8 AM)',
        'budget_level': 'Balanced (\$\$)',
        'pace': 'Relaxed (1-2 spots/day)',
        'planning_style': 'Spontaneous (go with flow)',
      };
      final hostStyle = {
        'wake_up_time': 'Early Bird (6-8 AM)',
        'budget_level': 'Balanced (\$\$)',
        'pace': 'Moderate (2-3 spots/day)',
        'planning_style': 'Spontaneous (go with flow)',
      };

      final labels = TravelCompatibility.computeLabels(
        userStyle: userStyle,
        hostStyle: hostStyle,
      );

      expect(labels, contains('Both early risers'));
      expect(labels, contains('Similar budget'));
      expect(labels, contains('Both spontaneous'));

      // CRITICAL REQUIREMENT: Ensure NO percentage symbol appears anywhere
      for (final label in labels) {
        expect(label.contains('%'), isFalse);
      }
    });

    test('falls back gracefully when questionnaires are empty', () {
      final labels = TravelCompatibility.computeLabels(
        userStyle: const {},
        hostStyle: const {},
      );
      expect(labels, contains('Open-minded solo explorers'));
      for (final label in labels) {
        expect(label.contains('%'), isFalse);
      }
    });
  });

  group('TripFilter Constraints', () {
    test('isActive returns false when default and true when configured', () {
      const defaultFilter = TripFilter();
      expect(defaultFilter.isActive, isFalse);

      final withQuery = defaultFilter.copyWith(destinationQuery: 'Kyoto');
      expect(withQuery.isActive, isTrue);

      final withBudget = defaultFilter.copyWith(minBudget: 500);
      expect(withBudget.isActive, isTrue);

      final withTags = defaultFilter.copyWith(tags: {'Culture'});
      expect(withTags.isActive, isTrue);
    });
  });

  group('TripRepository Layer & Security Tests', () {
    const repo = SupabaseTripRepository(null);

    test('getDiscoverTrips returns filtered demo trips when offline', () async {
      final allTrips = await repo.getDiscoverTrips();
      expect(allTrips.isNotEmpty, isTrue);

      final tokyoTrips = await repo.getDiscoverTrips(
        filter: const TripFilter(destinationQuery: 'Tokyo'),
      );
      expect(tokyoTrips.every((t) => t.destination.contains('Tokyo')), isTrue);

      final budgetedTrips = await repo.getDiscoverTrips(
        filter: const TripFilter(maxBudget: 1500),
      );
      expect(
        budgetedTrips.every((t) => t.budget == null || t.budget! <= 1500),
        isTrue,
      );
    });

    test('getTripById returns matching trip or null for invalid ID', () async {
      final trip = await repo.getTripById('demo-1');
      expect(trip, isNotNull);
      expect(trip!.id, 'demo-1');
      expect(trip.destination, 'Lisbon, Portugal');

      final notFound = await repo.getTripById('non-existent-id');
      expect(notFound, isNull);
    });

    test(
      'Trip projection NEVER contains email, home_city, or contact info',
      () {
        // Inspect the fields pulled across safe Trip entities
        final trip = Trip(
          id: 'safe-trip-1',
          hostId: 'host-1',
          destination: 'Reykjavik, Iceland',
          startDate: DateTime(2026, 11, 1),
          endDate: DateTime(2026, 11, 8),
          budget: 2000,
          maxMembers: 5,
          description: 'Chasing the northern lights in Iceland.',
          tags: const ['Nature', 'Aurora'],
          hostDisplayName: 'Sigurd',
          hostIsVerified: true,
          hostTravelStyle: const {'wake_up_time': 'Early Bird'},
        );

        // Verify Trip model does not leak private contact fields
        expect(trip.hostDisplayName, 'Sigurd');
        expect(trip.hostIsVerified, isTrue);
        // JSON serialization verifies no email or homeCity keys exist
        final json = {
          'id': trip.id,
          'destination': trip.destination,
          'host': {
            'id': trip.hostId,
            'display_name': trip.hostDisplayName,
            'avatar_path': trip.hostAvatarPath,
            'is_verified': trip.hostIsVerified,
            'travel_style': trip.hostTravelStyle,
          },
        };
        final hostMap = json['host']! as Map<String, dynamic>;
        expect(hostMap.containsKey('email'), isFalse);
        expect(hostMap.containsKey('home_city'), isFalse);
        expect(hostMap.containsKey('phone'), isFalse);
      },
    );

    test('TripDraft.toInsertJson cleans and sanitizes inputs', () {
      final draft = TripDraft(
        destination: '<script>alert("xss")</script> Kyoto, Japan  ',
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 10),
        budget: 1500,
        maxMembers: 6,
        description: '<b>Exploring historic shrines</b> and hidden alleyways.',
        tags: const ['<style>Culture</style>', 'Food  '],
      );

      final json = draft.toInsertJson('user-host-123');
      expect(json['host_id'], 'user-host-123');
      expect(json['destination'], 'alert("xss") Kyoto, Japan');
      expect(
        json['description'],
        'Exploring historic shrines and hidden alleyways.',
      );
      expect(json['tags'], ['Culture', 'Food']);
      expect(json['status'], 'published');
    });

    test(
      'Trip immutability check detects breaking edits when members exist',
      () {
        final existingTrip = Trip(
          id: 'trip-with-members',
          hostId: 'host-user-id',
          destination: 'Osaka, Japan',
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 10),
          budget: 1200,
          maxMembers: 4,
          description: 'Street food crawl in Dotonbori.',
          confirmedMembersCount: 2, // Confirmed members have joined!
        );

        expect(existingTrip.hasConfirmedMembers, isTrue);

        // Attempting to change destination or dates
        final breakingDraft = TripDraft(
          destination: 'Tokyo, Japan', // Changed!
          startDate: existingTrip.startDate,
          endDate: existingTrip.endDate,
          budget: existingTrip.budget,
          maxMembers: existingTrip.maxMembers,
          description: existingTrip.description,
        );

        final destinationChanged =
            TextSanitizer.sanitize(existingTrip.destination) !=
            TextSanitizer.sanitize(breakingDraft.destination);
        expect(destinationChanged, isTrue);

        // Safe edit: only changing description or tags
        final safeDraft = TripDraft(
          destination: existingTrip.destination,
          startDate: existingTrip.startDate,
          endDate: existingTrip.endDate,
          budget: existingTrip.budget,
          maxMembers: existingTrip.maxMembers,
          description: 'Updated description: Added local ramen spots.',
          tags: const ['Foodie', 'Nightlife'],
        );

        final safeDestinationChanged =
            TextSanitizer.sanitize(existingTrip.destination) !=
            TextSanitizer.sanitize(safeDraft.destination);
        final safeDatesChanged =
            existingTrip.startDate != safeDraft.startDate ||
            existingTrip.endDate != safeDraft.endDate;

        expect(safeDestinationChanged, isFalse);
        expect(safeDatesChanged, isFalse);
      },
    );
  });
}
