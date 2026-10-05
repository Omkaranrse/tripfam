class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.bio,
    this.homeCity,
    this.avatarPath,
    this.travelStyle = const {},
    this.isVerified = false,
    this.role = 'user',
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?)?.trim() ?? '',
      bio: (json['bio'] as String?)?.trim(),
      homeCity: (json['home_city'] as String?)?.trim(),
      avatarPath: json['avatar_path'] as String?,
      travelStyle: (json['travel_style'] as Map<String, dynamic>?) ?? const {},
      isVerified: json['is_verified'] as bool? ?? false,
      role: json['role'] as String? ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  final String id;
  final String displayName;
  final String? bio;
  final String? homeCity;
  final String? avatarPath;
  final Map<String, dynamic> travelStyle;
  final bool isVerified;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isProfileComplete =>
      displayName.trim().length >= 2 &&
      (homeCity?.trim().isNotEmpty ?? false) &&
      travelStyle.isNotEmpty;

  Map<String, dynamic> toUpdateJson() {
    return {
      'display_name': displayName.trim(),
      'bio': bio?.trim(),
      'home_city': homeCity?.trim(),
      'avatar_path': avatarPath,
      'travel_style': travelStyle,
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? homeCity,
    String? avatarPath,
    Map<String, dynamic>? travelStyle,
    bool? isVerified,
    String? role,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      homeCity: homeCity ?? this.homeCity,
      avatarPath: avatarPath ?? this.avatarPath,
      travelStyle: travelStyle ?? this.travelStyle,
      isVerified: isVerified ?? this.isVerified,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
