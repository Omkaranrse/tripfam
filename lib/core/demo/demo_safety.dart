import '../../features/safety/domain/safety_models.dart';

/// Preconfigured safety status and emergency contacts for the demo user.
abstract final class DemoSafety {
  static final DateTime _now = DateTime.now();

  /// 2/3 Trusted emergency contacts with masked phone numbers.
  static final List<TrustedContact> trustedContacts = [
    const TrustedContact(
      id: 'contact-mother',
      name: 'Aai (Mother)',
      relationship: 'Mother',
      phoneNumber: '+91 98201 XXXXX',
      email: 'family.anarse@example.com',
    ),
    const TrustedContact(
      id: 'contact-brother',
      name: 'Rohan Anarse',
      relationship: 'Brother',
      phoneNumber: '+91 98192 XXXXX',
      email: 'rohan.anarse@example.com',
    ),
  ];

  /// Live check-in schedule for active departure:
  /// On Track, 12 hour interval, next check-in due in 11 hours 42 minutes, last check-in 2 hours ago.
  static TripCheckinSchedule get checkinSchedule {
    return TripCheckinSchedule(
      id: 'schedule-alibaug',
      tripId: 'trip-alibaug',
      intervalHours: 12,
      isActive: true,
      lastCheckinAt: _now.subtract(const Duration(hours: 2, minutes: 18)),
      nextCheckinDueAt: _now.add(const Duration(hours: 11, minutes: 42)),
      alertSent: false,
    );
  }

  /// Live location status (disabled by default as per specification).
  static TripLiveLocation get liveLocation {
    return TripLiveLocation(
      tripId: 'trip-alibaug',
      latitude: 18.9220, // Gateway of India / Mumbai Port coords
      longitude: 72.8347,
      accuracyMeters: 10.0,
      isSharingEnabled: false,
      updatedAt: _now.subtract(const Duration(hours: 2)),
    );
  }

  /// List of blocked users (empty for clean demo experience).
  static const List<BlockedUser> blockedUsers = [];
}
