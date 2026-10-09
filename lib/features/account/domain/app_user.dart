import 'package:firebase_auth/firebase_auth.dart' as fb;

class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    Map<String, dynamic>? userMetadata,
  }) : _userMetadata = userMetadata;

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final Map<String, dynamic>? _userMetadata;

  Map<String, dynamic> get userMetadata =>
      _userMetadata ??
      {
        'display_name': displayName,
        'email': email,
        'photo_url': photoUrl,
      };

  factory AppUser.fromFirebaseUser(fb.User user) {
    return AppUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      userMetadata: {
        'display_name': user.displayName,
        'email': user.email,
        'photo_url': user.photoURL,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
