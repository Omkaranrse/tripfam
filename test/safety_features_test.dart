import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/features/safety/domain/safety_models.dart';

void main() {
  group('TrustedContact Security & Domain Model Tests', () {
    test('TrustedContact.fromJson parses contact data safely and handles relationship fallback', () {
      final json = {
        'id': 'contact-1',
        'name': '<b>Jane Doe</b>',
        'relationship': '',
        'phone_number': '+1 555 987 6543',
        'email': 'jane@example.com',
      };

      final contact = TrustedContact.fromJson(json);
      expect(contact.id, equals('contact-1'));
      expect(contact.name, equals('Jane Doe'));
      expect(contact.relationship, equals('Emergency Contact'));
      expect(contact.phoneNumber, equals('+1 555 987 6543'));
      expect(contact.email, equals('jane@example.com'));
    });

    test('TrustedContact.toJson contains provided contact reach fields', () {
      const emailOnly = TrustedContact(
        id: 'c-1',
        name: 'Alex',
        email: 'alex@example.com',
      );
      final json = emailOnly.toJson();
      expect(json['name'], equals('Alex'));
      expect(json['email'], equals('alex@example.com'));
      expect(json.containsKey('phone_number'), isFalse);

      const phoneOnly = TrustedContact(
        id: 'c-2',
        name: 'Bob',
        phoneNumber: '+1 234 567 8900',
      );
      final phoneJson = phoneOnly.toJson();
      expect(phoneJson['phone_number'], equals('+1 234 567 8900'));
      expect(phoneJson.containsKey('email'), isFalse);
    });
  });

  group('TripCheckinSchedule & Deadline Tests', () {
    test(
      'TripCheckinSchedule detects overdue check-in when deadline has passed',
      () {
        final pastDue = TripCheckinSchedule(
          id: 's-1',
          tripId: 'trip-1',
          intervalHours: 12,
          isActive: true,
          lastCheckinAt: DateTime.now().subtract(const Duration(hours: 13)),
          nextCheckinDueAt: DateTime.now().subtract(
            const Duration(minutes: 30),
          ),
          alertSent: false,
        );

        expect(pastDue.isOverdue, isTrue);
        expect(pastDue.timeUntilDue!.isNegative, isTrue);
      },
    );

    test('TripCheckinSchedule recognizes active on-time check-in window', () {
      final onTime = TripCheckinSchedule(
        id: 's-2',
        tripId: 'trip-1',
        intervalHours: 12,
        isActive: true,
        lastCheckinAt: DateTime.now().subtract(const Duration(hours: 2)),
        nextCheckinDueAt: DateTime.now().add(const Duration(hours: 10)),
        alertSent: false,
      );

      expect(onTime.isOverdue, isFalse);
      expect(onTime.timeUntilDue!.isNegative, isFalse);
      expect(onTime.timeUntilDue!.inHours, greaterThanOrEqualTo(9));
    });

    test(
      'TripCheckinSchedule.fromJson correctly parses interval and timestamps',
      () {
        final json = {
          'id': 's-3',
          'trip_id': 'trip-99',
          'interval_hours': 6,
          'is_active': true,
          'last_checkin_at': '2026-10-03T10:00:00Z',
          'next_checkin_due_at': '2026-10-03T16:00:00Z',
          'alert_sent': true,
        };

        final schedule = TripCheckinSchedule.fromJson(json);
        expect(schedule.id, equals('s-3'));
        expect(schedule.intervalHours, equals(6));
        expect(schedule.isActive, isTrue);
        expect(schedule.alertSent, isTrue);
        expect(schedule.lastCheckinAt, isNotNull);
        expect(schedule.nextCheckinDueAt, isNotNull);
      },
    );
  });

  group('TripLiveLocation Model Tests', () {
    test('TripLiveLocation parses GPS coordinates and opt-in state', () {
      final json = {
        'trip_id': 'trip-tokyo',
        'latitude': 35.6762,
        'longitude': 139.6503,
        'accuracy_meters': 15.5,
        'is_sharing_enabled': true,
        'updated_at': '2026-10-03T14:00:00Z',
      };

      final loc = TripLiveLocation.fromJson(json);
      expect(loc.tripId, equals('trip-tokyo'));
      expect(loc.latitude, closeTo(35.6762, 0.0001));
      expect(loc.longitude, closeTo(139.6503, 0.0001));
      expect(loc.accuracyMeters, equals(15.5));
      expect(loc.isSharingEnabled, isTrue);
    });
  });

  group('BlockedUser Domain Tests', () {
    test('BlockedUser.fromJson extracts profile display name safely', () {
      final json = {
        'id': 'b-1',
        'blocked_id': 'user-spammer',
        'created_at': '2026-10-01T08:00:00Z',
        'blocked_profile': {
          'id': 'user-spammer',
          'display_name': '<i>Spammer Jack</i>',
          'avatar_path': 'avatars/spammer.jpg',
        },
      };

      final blocked = BlockedUser.fromJson(json);
      expect(blocked.id, equals('b-1'));
      expect(blocked.blockedId, equals('user-spammer'));
      expect(blocked.displayName, equals('Spammer Jack'));
      expect(blocked.avatarPath, equals('avatars/spammer.jpg'));
    });
  });
}
