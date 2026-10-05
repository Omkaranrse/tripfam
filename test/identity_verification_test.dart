import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/features/account/domain/verification_models.dart';
import 'package:tripfam/features/trips/domain/trip.dart';

void main() {
  group('VerificationStatus & UserVerificationState Tests', () {
    test(
      'VerificationStatus.fromString maps known strings and defaults correctly',
      () {
        expect(
          VerificationStatus.fromString('not_submitted'),
          equals(VerificationStatus.notSubmitted),
        );
        expect(
          VerificationStatus.fromString('pending'),
          equals(VerificationStatus.pending),
        );
        expect(
          VerificationStatus.fromString('verified'),
          equals(VerificationStatus.verified),
        );
        expect(
          VerificationStatus.fromString('rejected'),
          equals(VerificationStatus.rejected),
        );
        expect(
          VerificationStatus.fromString('unknown_status'),
          equals(VerificationStatus.notSubmitted),
        );
      },
    );

    test(
      'UserVerificationState.fromJson correctly parses pending review state',
      () {
        final json = {
          'status': 'pending',
          'is_verified': false,
          'submitted_at': '2026-10-03T12:00:00Z',
          'instruction_completed': 'Turn your head to the left',
        };

        final state = UserVerificationState.fromJson(json);
        expect(state.status, equals(VerificationStatus.pending));
        expect(state.isPending, isTrue);
        expect(state.isVerified, isFalse);
        expect(
          state.instructionCompleted,
          equals('Turn your head to the left'),
        );
        expect(state.submittedAt, isNotNull);
        expect(state.rejectionReason, isNull);
      },
    );

    test('UserVerificationState.fromJson correctly parses rejected state with reviewer reason', () {
      final json = {
        'status': 'rejected',
        'is_verified': false,
        'rejection_reason': 'Selfie did not match the pose instruction.',
        'reviewed_at': '2026-10-03T14:30:00Z',
      };

      final state = UserVerificationState.fromJson(json);
      expect(state.status, equals(VerificationStatus.rejected));
      expect(state.isRejected, isTrue);
      expect(state.isVerified, isFalse);
      expect(
        state.rejectionReason,
        equals('Selfie did not match the pose instruction.'),
      );
      expect(state.reviewedAt, isNotNull);
    });

    test('UserVerificationState.fromJson handles verified state', () {
      final json = {
        'status': 'verified',
        'is_verified': true,
        'reviewed_at': '2026-10-03T15:00:00Z',
      };

      final state = UserVerificationState.fromJson(json);
      expect(state.status, equals(VerificationStatus.verified));
      expect(state.isVerified, isTrue);
      expect(state.isPending, isFalse);
    });
  });

  group('VerificationInstruction Tests', () {
    test('Random instruction is always selected from pool', () {
      final instruction = VerificationInstruction.getRandom();
      expect(VerificationInstruction.all, contains(instruction));
      expect(instruction.title, isNotEmpty);
      expect(instruction.instruction, isNotEmpty);
      expect(instruction.id, isNotEmpty);
    });

    test('Instruction pool contains required live pose actions', () {
      final ids = VerificationInstruction.all.map((i) => i.id).toSet();
      expect(ids.contains('turn_left'), isTrue);
      expect(ids.contains('turn_right'), isTrue);
      expect(ids.contains('smile'), isTrue);
      expect(ids.contains('look_up'), isTrue);
    });
  });

  group('AdminVerificationItem Model Tests', () {
    test('AdminVerificationItem.fromJson parses queue items accurately', () {
      final json = {
        'id': 'req-12345',
        'user_id': 'user-9876',
        'display_name': 'Marco Polo',
        'profile_avatar_path': 'avatars/user-9876/avatar.jpg',
        'selfie_storage_path': 'verification-selfies/user-9876/selfie_123.jpg',
        'instruction_completed': 'Smile warmly at the camera',
        'submitted_at': '2026-10-03T16:00:00Z',
      };

      final item = AdminVerificationItem.fromJson(json);
      expect(item.id, equals('req-12345'));
      expect(item.userId, equals('user-9876'));
      expect(item.displayName, equals('Marco Polo'));
      expect(item.profileAvatarPath, equals('avatars/user-9876/avatar.jpg'));
      expect(
        item.selfieStoragePath,
        equals('verification-selfies/user-9876/selfie_123.jpg'),
      );
      expect(item.instructionCompleted, equals('Smile warmly at the camera'));
      expect(item.submittedAt.year, equals(2026));
    });

    test(
      'AdminVerificationItem handles missing or null optional fields safely',
      () {
        final json = {
          'id': 'req-999',
          'user_id': 'user-111',
          'display_name': null,
          'profile_avatar_path': null,
          'selfie_storage_path': 'selfie.jpg',
          'instruction_completed': 'Turn head left',
          'submitted_at': '2026-10-03T16:00:00Z',
        };

        final item = AdminVerificationItem.fromJson(json);
        expect(item.displayName, equals('Traveller'));
        expect(item.profileAvatarPath, isNull);
      },
    );
  });

  group('Trip Verification Gating Domain Tests', () {
    test('TripDraft default requiresVerifiedMembers is false', () {
      final draft = TripDraft(
        destination: 'Tokyo, Japan',
        startDate: DateTime.now().add(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 14)),
        maxMembers: 4,
        description: 'Explore shrines and modern streets in Tokyo.',
        tags: const ['Culture', 'Foodie'],
      );

      expect(draft.requiresVerifiedMembers, isFalse);
      final json = draft.toInsertJson('host-1');
      expect(json['requires_verified_members'], isFalse);
    });

    test(
      'TripDraft with requiresVerifiedMembers = true reflects in insert JSON',
      () {
        final draft = TripDraft(
          destination: 'Reykjavik, Iceland',
          startDate: DateTime.now().add(const Duration(days: 30)),
          endDate: DateTime.now().add(const Duration(days: 40)),
          maxMembers: 6,
          description: 'Ring road road-trip with hot springs and glaciers.',
          tags: const ['Nature', 'Roadtrip'],
          requiresVerifiedMembers: true,
        );

        expect(draft.requiresVerifiedMembers, isTrue);
        final json = draft.toInsertJson('host-1');
        expect(json['requires_verified_members'], isTrue);
      },
    );

    test('Trip.fromJson parses requires_verified_members accurately', () {
      final json = {
        'id': 'trip-verified-1',
        'host_id': 'host-1',
        'destination': 'Patagonia Trekking',
        'start_date': '2026-11-01',
        'end_date': '2026-11-15',
        'budget': 2500,
        'max_members': 6,
        'tags': ['Trekking', 'Outdoors'],
        'description': 'Hiking Fitz Roy and Torres del Paine.',
        'status': 'open',
        'confirmed_member_count': 1,
        'requires_verified_members': true,
      };

      final trip = Trip.fromJson(json);
      expect(trip.requiresVerifiedMembers, isTrue);
    });
  });
}
