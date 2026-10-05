import '../../features/trips/domain/join_request.dart';
import 'demo_users.dart';

/// Curated join requests and intro call state machine fixtures.
abstract final class DemoRequests {
  static final DateTime _now = DateTime.now();

  /// Join requests submitted by the current demo user (Omkar) to other trips.
  static List<JoinRequest> get myOutgoingRequests {
    return [
      // 1. Alibaug: Both Confirmed -> Chat Unlocked!
      JoinRequest(
        id: 'req-omkar-alibaug',
        tripId: 'trip-alibaug',
        tripDestination: 'Alibaug, Maharashtra',
        tripHostId: DemoUsers.aarav.id,
        userId: DemoUsers.currentUser.id,
        status: 'accepted',
        message:
            'Hey Aarav! Super excited for this. I live in Dadar so I can easily catch the early ferry at Bhaucha Dhakka.',
        createdAt: _now.subtract(const Duration(days: 3)),
        applicant: ApplicantProfile(
          id: DemoUsers.currentUser.id,
          displayName: DemoUsers.currentUser.displayName,
          avatarPath: DemoUsers.currentUser.avatarPath,
          isVerified: DemoUsers.currentUser.isVerified,
          travelStyle: DemoUsers.currentUser.travelStyle,
        ),
        introCall: IntroCall(
          id: 'call-alibaug-omkar',
          requestId: 'req-omkar-alibaug',
          scheduledAt: _now.subtract(const Duration(days: 1)),
          meetingLink: 'https://meet.google.com/xyz-alibaug-meet',
          hostConfirmed: true,
          travellerConfirmed: true,
          createdAt: _now.subtract(const Duration(days: 2)),
          updatedAt: _now.subtract(const Duration(days: 1)),
        ),
      ),

      // 2. Goa: Call Scheduled (Saturday 7:30 PM) -> Waiting for confirmation
      JoinRequest(
        id: 'req-omkar-goa',
        tripId: 'trip-goa',
        tripDestination: 'North Goa',
        tripHostId: DemoUsers.riya.id,
        userId: DemoUsers.currentUser.id,
        status: 'accepted',
        message:
            'Hey Riya, would love to join for the Goa road trip! I can help take turns driving.',
        createdAt: _now.subtract(const Duration(days: 2)),
        applicant: ApplicantProfile(
          id: DemoUsers.currentUser.id,
          displayName: DemoUsers.currentUser.displayName,
          avatarPath: DemoUsers.currentUser.avatarPath,
          isVerified: DemoUsers.currentUser.isVerified,
          travelStyle: DemoUsers.currentUser.travelStyle,
        ),
        introCall: IntroCall(
          id: 'call-goa-omkar',
          requestId: 'req-omkar-goa',
          scheduledAt: _now.add(const Duration(days: 1, hours: 8)),
          meetingLink: 'https://meet.google.com/goa-intro-call',
          hostConfirmed: true,
          travellerConfirmed: false,
          createdAt: _now.subtract(const Duration(days: 1)),
        ),
      ),

      // 3. Gokarna: Pending Request
      JoinRequest(
        id: 'req-omkar-gokarna',
        tripId: 'trip-gokarna',
        tripDestination: 'Gokarna, Karnataka',
        tripHostId: DemoUsers.meera.id,
        userId: DemoUsers.currentUser.id,
        status: 'pending',
        message:
            'Hey Meera! I have been meaning to do the Om Beach cliff trek. Happy to pack a portable stove for beach coffee!',
        createdAt: _now.subtract(const Duration(hours: 14)),
        applicant: ApplicantProfile(
          id: DemoUsers.currentUser.id,
          displayName: DemoUsers.currentUser.displayName,
          avatarPath: DemoUsers.currentUser.avatarPath,
          isVerified: DemoUsers.currentUser.isVerified,
          travelStyle: DemoUsers.currentUser.travelStyle,
        ),
      ),

      // 4. Kasol: Accepted but Call Not Yet Scheduled
      JoinRequest(
        id: 'req-omkar-kasol',
        tripId: 'trip-kasol',
        tripDestination: 'Kasol, Himachal Pradesh',
        tripHostId: DemoUsers.ishaan.id,
        userId: DemoUsers.currentUser.id,
        status: 'accepted',
        message:
            'Hey Ishaan! Down for the Parvati valley retreat. Looking forward to connecting!',
        createdAt: _now.subtract(const Duration(days: 4)),
        applicant: ApplicantProfile(
          id: DemoUsers.currentUser.id,
          displayName: DemoUsers.currentUser.displayName,
          avatarPath: DemoUsers.currentUser.avatarPath,
          isVerified: DemoUsers.currentUser.isVerified,
          travelStyle: DemoUsers.currentUser.travelStyle,
        ),
        introCall: const IntroCall(
          id: 'call-kasol-omkar',
          requestId: 'req-omkar-kasol',
          hostConfirmed: false,
          travellerConfirmed: false,
        ),
      ),

      // 5. Rajmachi: Declined Request
      JoinRequest(
        id: 'req-omkar-rajmachi',
        tripId: 'trip-rajmachi',
        tripDestination: 'Rajmachi Fort, Lonavala',
        tripHostId: DemoUsers.neha.id,
        userId: DemoUsers.currentUser.id,
        status: 'declined',
        message: 'Hey Neha! Love monsoon fort treks. Hope to join!',
        createdAt: _now.subtract(const Duration(days: 5)),
        applicant: ApplicantProfile(
          id: DemoUsers.currentUser.id,
          displayName: DemoUsers.currentUser.displayName,
          avatarPath: DemoUsers.currentUser.avatarPath,
          isVerified: DemoUsers.currentUser.isVerified,
          travelStyle: DemoUsers.currentUser.travelStyle,
        ),
      ),
    ];
  }

  /// Incoming join requests received for trips hosted by Omkar.
  static List<JoinRequest> get incomingRequestsForHostedTrips {
    return [
      // For Trip 16: Khandala Cliffside Camping
      JoinRequest(
        id: 'req-riya-khandala',
        tripId: 'trip-khandala',
        tripDestination: 'Khandala, Maharashtra',
        tripHostId: DemoUsers.currentUser.id,
        userId: DemoUsers.riya.id,
        status: 'accepted',
        message:
            'Hey Omkar! I can bring my camera gear for stargazing and astrophotography on the cliff.',
        createdAt: _now.subtract(const Duration(days: 2)),
        applicant: ApplicantProfile(
          id: DemoUsers.riya.id,
          displayName: DemoUsers.riya.displayName,
          avatarPath: DemoUsers.riya.avatarPath,
          isVerified: DemoUsers.riya.isVerified,
          travelStyle: DemoUsers.riya.travelStyle,
        ),
        introCall: IntroCall(
          id: 'call-khandala-riya',
          requestId: 'req-riya-khandala',
          scheduledAt: _now.add(const Duration(days: 1)),
          meetingLink: 'https://meet.google.com/khandala-intro',
          hostConfirmed: true,
          travellerConfirmed: true,
          createdAt: _now.subtract(const Duration(days: 1)),
        ),
      ),

      JoinRequest(
        id: 'req-rohan-khandala',
        tripId: 'trip-khandala',
        tripDestination: 'Khandala, Maharashtra',
        tripHostId: DemoUsers.currentUser.id,
        userId: DemoUsers.rohan.id,
        status: 'pending',
        message:
            'Hey! I have a 7-seater SUV with roof racks for camping tents. Would love to join the gang.',
        createdAt: _now.subtract(const Duration(hours: 8)),
        applicant: ApplicantProfile(
          id: DemoUsers.rohan.id,
          displayName: DemoUsers.rohan.displayName,
          avatarPath: DemoUsers.rohan.avatarPath,
          isVerified: DemoUsers.rohan.isVerified,
          travelStyle: DemoUsers.rohan.travelStyle,
        ),
      ),

      // For Trip 17: Dudhsagar Waterfalls
      JoinRequest(
        id: 'req-kabir-dudhsagar',
        tripId: 'trip-dudhsagar',
        tripDestination: 'Dudhsagar, Goa Border',
        tripHostId: DemoUsers.currentUser.id,
        userId: DemoUsers.kabir.id,
        status: 'accepted',
        message:
            'Hey Omkar! I have done the Dudhsagar railway trek before and know the local guides at Kulem.',
        createdAt: _now.subtract(const Duration(days: 4)),
        applicant: ApplicantProfile(
          id: DemoUsers.kabir.id,
          displayName: DemoUsers.kabir.displayName,
          avatarPath: DemoUsers.kabir.avatarPath,
          isVerified: DemoUsers.kabir.isVerified,
          travelStyle: DemoUsers.kabir.travelStyle,
        ),
        introCall: IntroCall(
          id: 'call-dudhsagar-kabir',
          requestId: 'req-kabir-dudhsagar',
          scheduledAt: _now.subtract(const Duration(days: 2)),
          meetingLink: 'https://meet.google.com/dudhsagar-chat',
          hostConfirmed: true,
          travellerConfirmed: true,
          createdAt: _now.subtract(const Duration(days: 3)),
        ),
      ),

      JoinRequest(
        id: 'req-ananya-dudhsagar',
        tripId: 'trip-dudhsagar',
        tripDestination: 'Dudhsagar, Goa Border',
        tripHostId: DemoUsers.currentUser.id,
        userId: DemoUsers.ananya.id,
        status: 'accepted',
        message: 'Waterfalls and off-roading? Sign me up! Excited to meet.',
        createdAt: _now.subtract(const Duration(days: 3)),
        applicant: ApplicantProfile(
          id: DemoUsers.ananya.id,
          displayName: DemoUsers.ananya.displayName,
          avatarPath: DemoUsers.ananya.avatarPath,
          isVerified: DemoUsers.ananya.isVerified,
          travelStyle: DemoUsers.ananya.travelStyle,
        ),
        introCall: IntroCall(
          id: 'call-dudhsagar-ananya',
          requestId: 'req-ananya-dudhsagar',
          scheduledAt: _now.subtract(const Duration(days: 1)),
          meetingLink: 'https://meet.google.com/dudhsagar-ananya',
          hostConfirmed: true,
          travellerConfirmed: true,
          createdAt: _now.subtract(const Duration(days: 2)),
        ),
      ),

      JoinRequest(
        id: 'req-neha-dudhsagar',
        tripId: 'trip-dudhsagar',
        tripDestination: 'Dudhsagar, Goa Border',
        tripHostId: DemoUsers.currentUser.id,
        userId: DemoUsers.neha.id,
        status: 'pending',
        message:
            'Hey Omkar, would love to join your Dudhsagar drive. Big monsoon waterfall enthusiast!',
        createdAt: _now.subtract(const Duration(hours: 18)),
        applicant: ApplicantProfile(
          id: DemoUsers.neha.id,
          displayName: DemoUsers.neha.displayName,
          avatarPath: DemoUsers.neha.avatarPath,
          isVerified: DemoUsers.neha.isVerified,
          travelStyle: DemoUsers.neha.travelStyle,
        ),
      ),
    ];
  }

  /// All join requests relevant for the current user.
  static List<JoinRequest> get allForUser {
    return [...myOutgoingRequests, ...incomingRequestsForHostedTrips];
  }

  /// Lookup requests for a specific trip.
  static List<JoinRequest> getRequestsForTrip(String tripId) {
    return allForUser.where((r) => r.tripId == tripId).toList();
  }

  /// Lookup request sent by current user for a trip.
  static JoinRequest? getMyRequestForTrip(String tripId) {
    try {
      return myOutgoingRequests.firstWhere((r) => r.tripId == tripId);
    } catch (_) {
      return null;
    }
  }
}
