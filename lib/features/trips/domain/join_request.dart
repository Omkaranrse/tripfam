import '../../../core/utils/text_sanitizer.dart';

/// The 5 defined progress stages in the join request state machine.
enum JoinRequestStage {
  requested,
  declined,
  cancelled,
  accepted,
  callScheduled,
  bothConfirmed;

  String get label {
    switch (this) {
      case JoinRequestStage.requested:
        return 'Request Sent';
      case JoinRequestStage.declined:
        return 'Declined';
      case JoinRequestStage.cancelled:
        return 'Cancelled';
      case JoinRequestStage.accepted:
        return 'Accepted · Needs Intro Call';
      case JoinRequestStage.callScheduled:
        return 'Intro Call Scheduled';
      case JoinRequestStage.bothConfirmed:
        return 'Confirmed · Chat Unlocked';
    }
  }

  int get stepIndex {
    switch (this) {
      case JoinRequestStage.requested:
        return 1;
      case JoinRequestStage.accepted:
        return 2;
      case JoinRequestStage.callScheduled:
        return 3;
      case JoinRequestStage.bothConfirmed:
        return 4;
      case JoinRequestStage.declined:
      case JoinRequestStage.cancelled:
        return 0;
    }
  }
}

class ApplicantProfile {
  const ApplicantProfile({
    required this.id,
    required this.displayName,
    this.avatarPath,
    this.isVerified = false,
    this.travelStyle = const {},
  });

  factory ApplicantProfile.fromJson(Map<String, dynamic> json) {
    return ApplicantProfile(
      id: json['id'] as String,
      displayName: () {
        final name = TextSanitizer.sanitize(json['display_name'] as String?);
        return name.isEmpty ? 'Adventurer' : name;
      }(),
      avatarPath: json['avatar_path'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      travelStyle: (json['travel_style'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String id;
  final String displayName;
  final String? avatarPath;
  final bool isVerified;
  final Map<String, dynamic> travelStyle;
}

class IntroCall {
  const IntroCall({
    required this.id,
    required this.requestId,
    this.scheduledAt,
    this.meetingLink,
    this.hostConfirmed = false,
    this.travellerConfirmed = false,
    this.createdAt,
    this.updatedAt,
  });

  factory IntroCall.fromJson(Map<String, dynamic> json) {
    return IntroCall(
      id: json['id'] as String,
      requestId: json['request_id'] as String,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'] as String)
          : null,
      meetingLink: json['meeting_link'] as String?,
      hostConfirmed: json['host_confirmed'] as bool? ?? false,
      travellerConfirmed: json['traveller_confirmed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String requestId;
  final DateTime? scheduledAt;
  final String? meetingLink;
  final bool hostConfirmed;
  final bool travellerConfirmed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isScheduled =>
      scheduledAt != null &&
      meetingLink != null &&
      meetingLink!.trim().isNotEmpty;
  bool get isBothConfirmed => hostConfirmed && travellerConfirmed;

  IntroCall copyWith({
    DateTime? scheduledAt,
    String? meetingLink,
    bool? hostConfirmed,
    bool? travellerConfirmed,
  }) {
    return IntroCall(
      id: id,
      requestId: requestId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      meetingLink: meetingLink ?? this.meetingLink,
      hostConfirmed: hostConfirmed ?? this.hostConfirmed,
      travellerConfirmed: travellerConfirmed ?? this.travellerConfirmed,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.status,
    this.tripDestination,
    this.tripHostId,
    this.message,
    this.createdAt,
    this.updatedAt,
    this.applicant,
    this.introCall,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final applicantData =
        json['profile'] as Map<String, dynamic>? ??
        json['profiles'] as Map<String, dynamic>?;

    final introCallData =
        json['intro_call'] as Map<String, dynamic>? ??
        (json['intro_calls'] is List && (json['intro_calls'] as List).isNotEmpty
            ? (json['intro_calls'] as List).first as Map<String, dynamic>
            : null);

    final tripData =
        json['trip'] as Map<String, dynamic>? ??
        json['trips'] as Map<String, dynamic>?;

    return JoinRequest(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      tripDestination: tripData?['destination'] as String?,
      tripHostId: tripData?['host_id'] as String?,
      userId: json['user_id'] as String,
      status: json['status'] as String? ?? 'pending',
      message: TextSanitizer.sanitize(json['message'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      applicant: applicantData != null
          ? ApplicantProfile.fromJson(applicantData)
          : null,
      introCall: introCallData != null
          ? IntroCall.fromJson(introCallData)
          : null,
    );
  }

  final String id;
  final String tripId;
  final String? tripDestination;
  final String? tripHostId;
  final String userId;
  final String status;
  final String? message;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ApplicantProfile? applicant;
  final IntroCall? introCall;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';

  JoinRequestStage get stage {
    if (isDeclined) return JoinRequestStage.declined;
    if (isCancelled) return JoinRequestStage.cancelled;
    if (isPending) return JoinRequestStage.requested;

    if (isAccepted) {
      if (introCall != null) {
        if (introCall!.isBothConfirmed) {
          return JoinRequestStage.bothConfirmed;
        }
        if (introCall!.isScheduled) {
          return JoinRequestStage.callScheduled;
        }
      }
      return JoinRequestStage.accepted;
    }

    return JoinRequestStage.requested;
  }

  bool get isChatUnlocked => stage == JoinRequestStage.bothConfirmed;

  JoinRequest copyWith({String? status, IntroCall? introCall}) {
    return JoinRequest(
      id: id,
      tripId: tripId,
      tripDestination: tripDestination,
      tripHostId: tripHostId,
      userId: userId,
      status: status ?? this.status,
      message: message,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      applicant: applicant,
      introCall: introCall ?? this.introCall,
    );
  }
}
