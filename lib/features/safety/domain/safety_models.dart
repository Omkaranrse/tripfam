import '../../../core/utils/text_sanitizer.dart';

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    this.relationship = 'Emergency Contact',
    this.phoneNumber,
    this.email,
  });

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: json['id'] as String,
      name: TextSanitizer.sanitize(json['name'] as String?),
      relationship: () {
        final rel = TextSanitizer.sanitize(json['relationship'] as String?);
        return rel.isNotEmpty ? rel : 'Emergency Contact';
      }(),
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
    );
  }

  final String id;
  final String name;
  final String relationship;
  final String? phoneNumber;
  final String? email;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relationship': relationship,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (email != null) 'email': email,
    };
  }
}

class TripCheckinSchedule {
  const TripCheckinSchedule({
    required this.id,
    required this.tripId,
    required this.intervalHours,
    required this.isActive,
    this.lastCheckinAt,
    this.nextCheckinDueAt,
    this.alertSent = false,
  });

  factory TripCheckinSchedule.fromJson(Map<String, dynamic> json) {
    return TripCheckinSchedule(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      intervalHours: (json['interval_hours'] as num?)?.toInt() ?? 12,
      isActive: json['is_active'] as bool? ?? true,
      lastCheckinAt: json['last_checkin_at'] != null
          ? DateTime.tryParse(json['last_checkin_at'] as String)
          : null,
      nextCheckinDueAt: json['next_checkin_due_at'] != null
          ? DateTime.tryParse(json['next_checkin_due_at'] as String)
          : null,
      alertSent: json['alert_sent'] as bool? ?? false,
    );
  }

  final String id;
  final String tripId;
  final int intervalHours;
  final bool isActive;
  final DateTime? lastCheckinAt;
  final DateTime? nextCheckinDueAt;
  final bool alertSent;

  bool get isOverdue {
    if (nextCheckinDueAt == null) return false;
    return DateTime.now().isAfter(nextCheckinDueAt!);
  }

  Duration? get timeUntilDue {
    if (nextCheckinDueAt == null) return null;
    return nextCheckinDueAt!.difference(DateTime.now());
  }
}

class TripLiveLocation {
  const TripLiveLocation({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.isSharingEnabled,
    this.accuracyMeters,
    this.updatedAt,
  });

  factory TripLiveLocation.fromJson(Map<String, dynamic> json) {
    return TripLiveLocation(
      tripId: json['trip_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
      isSharingEnabled: json['is_sharing_enabled'] as bool? ?? true,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String tripId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final bool isSharingEnabled;
  final DateTime? updatedAt;
}

class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.blockedId,
    required this.displayName,
    this.avatarPath,
    this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    final profile = json['blocked_profile'] as Map<String, dynamic>?;

    return BlockedUser(
      id: json['id'] as String,
      blockedId: json['blocked_id'] as String,
      displayName: profile != null
          ? (TextSanitizer.sanitize(profile['display_name'] as String?)
                    .isNotEmpty
                ? TextSanitizer.sanitize(profile['display_name'] as String?)
                : 'TripFam User')
          : 'TripFam User',
      avatarPath: profile?['avatar_path'] as String?,
      blockedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  final String id;
  final String blockedId;
  final String displayName;
  final String? avatarPath;
  final DateTime? blockedAt;
}
