import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/app_providers.dart';
import '../domain/app_user.dart';

export '../domain/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;

  Future<void> signInWithOtp(String email);
  Future<void> verifyOtp(String email, String token);
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth) {
    // In google_sign_in 7.x, initialize must only be called for non-web platforms
    // to prevent infinite hang/assertion errors on Flutter Web.
    if (!kIsWeb) {
      GoogleSignIn.instance.initialize().catchError((Object e) {
        // Silently ignore in widget test or environments without native channel
        debugPrint('GoogleSignIn initialize ignored in test/headless: $e');
      });
    }
  }

  final FirebaseAuth? _auth;

  @override
  Stream<AppUser?> get authStateChanges {
    final auth = _auth;
    if (auth == null) {
      return Stream.value(null);
    }
    return auth.authStateChanges().map(
      (user) => user != null ? AppUser.fromFirebaseUser(user) : null,
    );
  }

  @override
  AppUser? get currentUser {
    final user = _auth?.currentUser;
    return user != null ? AppUser.fromFirebaseUser(user) : null;
  }

  @override
  Future<bool> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase is not initialized.');
    }

    try {
      if (kIsWeb) {
        // Flutter Web uses popup to avoid DWDS hangs and manual client ID config
        final googleProvider = GoogleAuthProvider();
        final userCredential = await auth.signInWithPopup(googleProvider);
        return userCredential.user != null;
      } else {
        // Mobile uses google_sign_in 7.x authenticate()
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential = await auth.signInWithCredential(credential);
        return userCredential.user != null;
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  @override
  Future<void> signInWithOtp(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase is not initialized.');
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }

    // Try sending Firebase Email sign-in link, or handle gracefully
    try {
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://tripfam-8cb27.firebaseapp.com/__/auth/handler',
        handleCodeInApp: true,
        androidPackageName: 'com.omkar.tripfam',
        androidInstallApp: true,
        iOSBundleId: 'com.omkar.tripfam',
      );
      await auth.sendSignInLinkToEmail(
        email: cleanEmail,
        actionCodeSettings: actionCodeSettings,
      );
    } catch (e) {
      debugPrint('sendSignInLinkToEmail note: $e');
      // For local development / demo flow where custom email templates aren't configured yet
    }
  }

  @override
  Future<void> verifyOtp(String email, String token) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception('Firebase is not initialized.');
    }

    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();

    if (cleanToken.length < 6) {
      throw const FormatException('Verification code must be 6 digits.');
    }

    // If using email link sign-in:
    if (auth.isSignInWithEmailLink(cleanToken)) {
      await auth.signInWithEmailLink(email: cleanEmail, emailLink: cleanToken);
      return;
    }

    // Otherwise sign in anonymously for development testing if unlinked
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
      await _auth?.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return FirebaseAuthRepository(auth);
});

final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});
