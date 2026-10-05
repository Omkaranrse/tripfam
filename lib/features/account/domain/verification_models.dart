import 'dart:math';

enum VerificationStatus {
  notSubmitted,
  pending,
  verified,
  rejected;

  static VerificationStatus fromString(String? str) {
    if (str == null) return VerificationStatus.notSubmitted;
    final lower = str.toLowerCase().trim();
    switch (lower) {
      case 'verified':
      case 'approved':
        return VerificationStatus.verified;
      case 'pending':
        return VerificationStatus.pending;
      case 'rejected':
        return VerificationStatus.rejected;
      default:
        return VerificationStatus.notSubmitted;
    }
  }
}

class UserVerificationState {
  const UserVerificationState({
    required this.status,
    required this.isVerified,
    this.requestId,
    this.rejectionReason,
    this.instructionCompleted,
    this.createdAt,
    this.submittedAt,
    this.reviewedAt,
  });

  factory UserVerificationState.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'not_submitted';
    final isVerified = json['is_verified'] as bool? ?? false;
    final status = isVerified
        ? VerificationStatus.verified
        : VerificationStatus.fromString(statusStr);

    final submitted = json['submitted_at'] != null
        ? DateTime.tryParse(json['submitted_at'] as String)
        : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null);

    final reviewed = json['reviewed_at'] != null
        ? DateTime.tryParse(json['reviewed_at'] as String)
        : null;

    return UserVerificationState(
      status: status,
      isVerified: isVerified,
      requestId: json['request_id'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      instructionCompleted: json['instruction_completed'] as String?,
      createdAt: submitted,
      submittedAt: submitted,
      reviewedAt: reviewed,
    );
  }

  final VerificationStatus status;
  final bool isVerified;
  final String? requestId;
  final String? rejectionReason;
  final String? instructionCompleted;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  bool get isPending => status == VerificationStatus.pending;
  bool get isRejected => status == VerificationStatus.rejected;
  bool get isNotSubmitted => status == VerificationStatus.notSubmitted;
}

class AdminVerificationItem {
  const AdminVerificationItem({
    required this.requestId,
    required this.userId,
    required this.displayName,
    required this.selfieStoragePath,
    this.avatarPath,
    this.instructionCompleted,
    this.reviewerNotes,
    this.createdAt,
  });

  factory AdminVerificationItem.fromJson(Map<String, dynamic> json) {
    final created = json['submitted_at'] != null
        ? DateTime.tryParse(json['submitted_at'] as String)
        : (json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null);

    return AdminVerificationItem(
      requestId: (json['request_id'] ?? json['id'] ?? '') as String,
      userId: json['user_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Traveller',
      avatarPath:
          (json['avatar_path'] ?? json['profile_avatar_path']) as String?,
      selfieStoragePath: (json['selfie_storage_path'] ?? '') as String,
      instructionCompleted: json['instruction_completed'] as String?,
      reviewerNotes: json['reviewer_notes'] as String?,
      createdAt: created,
    );
  }

  final String requestId;
  final String userId;
  final String displayName;
  final String? avatarPath;
  final String selfieStoragePath;
  final String? instructionCompleted;
  final String? reviewerNotes;
  final DateTime? createdAt;

  String get id => requestId;
  String? get profileAvatarPath => avatarPath;
  DateTime get submittedAt => createdAt ?? DateTime.now();
}

class VerificationInstruction {
  const VerificationInstruction({
    required this.id,
    required this.title,
    required this.instruction,
  });

  final String id;
  final String title;
  final String instruction;

  static const List<VerificationInstruction> all = [
    VerificationInstruction(
      id: 'turn_left',
      title: 'Turn Head Left',
      instruction:
          'Turn your head slightly to the left while looking at the camera.',
    ),
    VerificationInstruction(
      id: 'turn_right',
      title: 'Turn Head Right',
      instruction:
          'Turn your head slightly to the right while looking at the camera.',
    ),
    VerificationInstruction(
      id: 'smile',
      title: 'Smile Warmly',
      instruction: 'Smile clearly and directly at the front camera.',
    ),
    VerificationInstruction(
      id: 'look_up',
      title: 'Tilt Head Up',
      instruction:
          'Tilt your chin slightly upwards while keeping eyes on the camera.',
    ),
  ];

  static VerificationInstruction getRandom([Random? random]) {
    final r = random ?? Random();
    return all[r.nextInt(all.length)];
  }
}
