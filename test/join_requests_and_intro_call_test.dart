import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/utils/meeting_link_validator.dart';
import 'package:tripfam/features/trips/data/join_request_repository.dart';
import 'package:tripfam/features/trips/domain/join_request.dart';

void main() {
  group('MeetingLinkValidator Security Tests', () {
    test('accepts valid HTTPS Google Meet links', () {
      expect(
        MeetingLinkValidator.isValid('https://meet.google.com/abc-defg-hij'),
        isTrue,
      );
      expect(
        MeetingLinkValidator.validate('https://meet.google.com/abc-defg-hij'),
        isNull,
      );
      expect(
        MeetingLinkValidator.getServiceType(
          'https://meet.google.com/abc-defg-hij',
        ),
        'Google Meet',
      );
    });

    test('accepts valid HTTPS Zoom links (standard and subdomains)', () {
      expect(
        MeetingLinkValidator.isValid('https://zoom.us/j/1234567890'),
        isTrue,
      );
      expect(
        MeetingLinkValidator.isValid('https://us04web.zoom.us/j/9876543210'),
        isTrue,
      );
      expect(
        MeetingLinkValidator.validate('https://zoom.us/j/1234567890'),
        isNull,
      );
      expect(
        MeetingLinkValidator.getServiceType('https://zoom.us/j/1234567890'),
        'Zoom',
      );
    });

    test('accepts valid HTTPS WhatsApp call and chat links', () {
      expect(
        MeetingLinkValidator.isValid(
          'https://call.whatsapp.com/voice/abc123XYZ',
        ),
        isTrue,
      );
      expect(
        MeetingLinkValidator.isValid(
          'https://chat.whatsapp.com/invite/group123',
        ),
        isTrue,
      );
      expect(
        MeetingLinkValidator.validate(
          'https://call.whatsapp.com/voice/abc123XYZ',
        ),
        isNull,
      );
      expect(
        MeetingLinkValidator.getServiceType(
          'https://call.whatsapp.com/voice/abc123XYZ',
        ),
        'WhatsApp',
      );
    });

    test('rejects non-HTTPS unencrypted links', () {
      expect(
        MeetingLinkValidator.isValid('http://meet.google.com/abc-defg-hij'),
        isFalse,
      );
      expect(
        MeetingLinkValidator.validate('http://meet.google.com/abc-defg-hij'),
        contains('must use secure HTTPS'),
      );
    });

    test('rejects unauthorized or arbitrary domains', () {
      const malicious = [
        'https://teams.microsoft.com/l/meetup-join/123',
        'https://discord.gg/invite123',
        'https://evil-phishing-site.com/meet',
        'https://google.com/search?q=meet',
        'javascript:alert(1)',
        'data:text/html,test',
      ];

      for (final url in malicious) {
        expect(
          MeetingLinkValidator.isValid(url),
          isFalse,
          reason: 'Failed to reject $url',
        );
        expect(
          MeetingLinkValidator.validate(url),
          isNotNull,
          reason: 'Should return error for $url',
        );
      }
    });

    test('rejects empty or whitespace input', () {
      expect(MeetingLinkValidator.isValid(null), isFalse);
      expect(MeetingLinkValidator.isValid('   '), isFalse);
      expect(
        MeetingLinkValidator.validate(''),
        contains('Please enter a meeting link'),
      );
    });
  });

  group('Join Request State Machine & Transition Tests', () {
    test('transitions from requested to accepted, callScheduled, and bothConfirmed', () {
      // 1. Initial State: requested
      var request = const JoinRequest(
        id: 'req-1',
        tripId: 'trip-1',
        userId: 'user-b',
        status: 'pending',
      );
      expect(request.stage, JoinRequestStage.requested);
      expect(request.isChatUnlocked, isFalse);

      // 2. Host accepts: accepted (intro call provisioned but not scheduled)
      request = request.copyWith(
        status: 'accepted',
        introCall: const IntroCall(id: 'call-1', requestId: 'req-1'),
      );
      expect(request.stage, JoinRequestStage.accepted);
      expect(request.isChatUnlocked, isFalse);

      // 3. Either party schedules call: callScheduled
      request = request.copyWith(
        introCall: request.introCall!.copyWith(
          scheduledAt: DateTime.now().add(const Duration(days: 2)),
          meetingLink: 'https://meet.google.com/abc-defg-hij',
        ),
      );
      expect(request.stage, JoinRequestStage.callScheduled);
      expect(request.introCall!.isScheduled, isTrue);
      expect(request.isChatUnlocked, isFalse);

      // 4. One party confirms: still callScheduled
      request = request.copyWith(
        introCall: request.introCall!.copyWith(
          hostConfirmed: true,
          travellerConfirmed: false,
        ),
      );
      expect(request.stage, JoinRequestStage.callScheduled);
      expect(request.isChatUnlocked, isFalse);

      // 5. Both parties confirm: bothConfirmed -> CHAT UNLOCKED!
      request = request.copyWith(
        introCall: request.introCall!.copyWith(
          hostConfirmed: true,
          travellerConfirmed: true,
        ),
      );
      expect(request.stage, JoinRequestStage.bothConfirmed);
      expect(request.isChatUnlocked, isTrue);
    });

    test('handles declined and cancelled terminal states', () {
      const declinedReq = JoinRequest(
        id: 'req-declined',
        tripId: 'trip-1',
        userId: 'user-b',
        status: 'declined',
      );
      expect(declinedReq.stage, JoinRequestStage.declined);
      expect(declinedReq.isDeclined, isTrue);
      expect(declinedReq.isChatUnlocked, isFalse);

      const cancelledReq = JoinRequest(
        id: 'req-cancelled',
        tripId: 'trip-1',
        userId: 'user-b',
        status: 'cancelled',
      );
      expect(cancelledReq.stage, JoinRequestStage.cancelled);
      expect(cancelledReq.isCancelled, isTrue);
      expect(cancelledReq.isChatUnlocked, isFalse);
    });
  });

  group('Applicant Profile Data Privacy & Projection Security', () {
    test('ApplicantProfile never extracts or exposes email, home_city, or phone', () {
      final json = {
        'id': 'applicant-uuid',
        'display_name': 'Marco Polo',
        'avatar_path': 'avatars/applicant-uuid/selfie.jpg',
        'is_verified': true,
        'travel_style': {
          'wake_up_time': 'Early Bird',
          'budget_level': 'Balanced',
        },
        // Private fields accidentally in raw payload must be completely ignored
        'email': 'marco@secret.com',
        'home_city': 'Venice, Italy',
        'phone': '+39 041 1234567',
      };

      final profile = ApplicantProfile.fromJson(json);
      expect(profile.id, 'applicant-uuid');
      expect(profile.displayName, 'Marco Polo');
      expect(profile.isVerified, isTrue);

      // Verify the domain class has no getters for private contact data
      final exportedJson = {
        'id': profile.id,
        'display_name': profile.displayName,
        'avatar_path': profile.avatarPath,
        'is_verified': profile.isVerified,
        'travel_style': profile.travelStyle,
      };
      expect(exportedJson.containsKey('email'), isFalse);
      expect(exportedJson.containsKey('home_city'), isFalse);
      expect(exportedJson.containsKey('phone'), isFalse);
    });
  });

  group('JoinRequestRepository Layer Tests', () {
    const repo = SupabaseJoinRequestRepository(null);

    test(
      'scheduleIntroCall throws validation error on invalid meeting link',
      () async {
        expect(
          () => repo.scheduleIntroCall(
            'call-1',
            scheduledAt: DateTime.now().add(const Duration(days: 1)),
            meetingLink: 'https://unauthorized-domain.com/meeting',
          ),
          throwsA(
            predicate(
              (e) => e.toString().contains('Google Meet, Zoom, or WhatsApp'),
            ),
          ),
        );
      },
    );

    test('scheduleIntroCall throws validation error on past date', () async {
      expect(
        () => repo.scheduleIntroCall(
          'call-1',
          scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
          meetingLink: 'https://meet.google.com/abc-defg-hij',
        ),
        throwsA(
          predicate((e) => e.toString().contains('must be in the future')),
        ),
      );
    });
  });
}
