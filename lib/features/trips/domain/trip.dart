import '../../../core/utils/text_sanitizer.dart';

class Trip {
  const Trip({
    required this.id,
    required this.hostId,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.maxMembers,
    required this.description,
    this.budget,
    this.tags = const [],
    this.status = 'published',
    this.hostDisplayName = 'Host',
    this.hostAvatarPath,
    this.hostIsVerified = false,
    this.hostTravelStyle = const {},
    this.confirmedMembersCount = 1, // Host counts as 1 member
    this.requiresVerifiedMembers = false,
    this.createdAt,
    this.updatedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    // RLS-safe host extraction: never contains email or home city
    final hostMap = json['host'] as Map<String, dynamic>?;

    final start = DateTime.parse(json['start_date'] as String);
    final end = DateTime.parse(json['end_date'] as String);

    final rawTags = json['tags'];
    final tagsList = rawTags is List
        ? rawTags.map((e) => TextSanitizer.sanitize(e.toString())).toList()
        : <String>[];

    final membersList = json['trip_members'] as List?;
    final membersCount = membersList != null && membersList.isNotEmpty
        ? membersList.length
        : 1;

    return Trip(
      id: json['id'] as String,
      hostId: json['host_id'] as String,
      destination: TextSanitizer.sanitize(json['destination'] as String?),
      startDate: start,
      endDate: end,
      budget: json['budget'] != null
          ? double.tryParse(json['budget'].toString())
          : null,
      maxMembers: json['max_members'] as int? ?? 4,
      description: TextSanitizer.sanitize(json['description'] as String?),
      tags: tagsList,
      status: json['status'] as String? ?? 'published',
      hostDisplayName: hostMap != null && hostMap['display_name'] != null
          ? TextSanitizer.sanitize(hostMap['display_name'] as String)
          : 'Adventurer',
      hostAvatarPath: hostMap?['avatar_path'] as String?,
      hostIsVerified: hostMap?['is_verified'] as bool? ?? false,
      hostTravelStyle:
          (hostMap?['travel_style'] as Map<String, dynamic>?) ?? const {},
      confirmedMembersCount: membersCount,
      requiresVerifiedMembers:
          json['requires_verified_members'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String hostId;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double? budget;
  final int maxMembers;
  final String description;
  final List<String> tags;
  final String status;
  final bool requiresVerifiedMembers;

  // Host safe display data
  final String hostDisplayName;
  final String? hostAvatarPath;
  final bool hostIsVerified;
  final Map<String, dynamic> hostTravelStyle;
  final int confirmedMembersCount;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get durationDays => endDate.difference(startDate).inDays + 1;
  int get availablePlaces {
    final places = maxMembers - confirmedMembersCount;
    return places > 0 ? places : 0;
  }

  bool get hasConfirmedMembers => confirmedMembersCount > 1;
}

class TripDraft {
  const TripDraft({
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.maxMembers,
    required this.description,
    this.budget,
    this.tags = const [],
    this.requiresVerifiedMembers = false,
  });

  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final double? budget;
  final int maxMembers;
  final String description;
  final List<String> tags;
  final bool requiresVerifiedMembers;

  String? validate() {
    final cleanDest = TextSanitizer.sanitize(destination);
    if (cleanDest.length < 2) {
      return 'Destination must be at least 2 characters.';
    }
    if (cleanDest.length > 150) {
      return 'Destination cannot exceed 150 characters.';
    }
    if (endDate.isBefore(startDate)) {
      return 'End date cannot be earlier than departure date.';
    }
    if (maxMembers < 2 || maxMembers > 12) {
      return 'Max members must be between 2 and 12 travellers.';
    }
    if (budget != null && budget! < 0) {
      return 'Budget cannot be negative.';
    }
    final cleanDesc = TextSanitizer.sanitize(description);
    if (cleanDesc.length < 10) {
      return 'Description must be at least 10 characters.';
    }
    if (cleanDesc.length > 5000) {
      return 'Description cannot exceed 5000 characters.';
    }
    return null;
  }

  Map<String, dynamic> toInsertJson(String hostId) {
    return {
      'host_id': hostId,
      'destination': TextSanitizer.sanitize(destination),
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'budget': budget,
      'max_members': maxMembers,
      'description': TextSanitizer.sanitize(description),
      'tags': tags.map(TextSanitizer.sanitize).toList(),
      'requires_verified_members': requiresVerifiedMembers,
      'status': 'published',
    };
  }
}
