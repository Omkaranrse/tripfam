import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/app_providers.dart';

abstract interface class AuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  Session? get currentSession;

  Future<void> signInWithOtp(String email);
  Future<AuthResponse> verifyOtp(String email, String token);
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient? _client;

  @override
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  @override
  User? get currentUser => _client?.auth.currentUser;

  @override
  Session? get currentSession => _client?.auth.currentSession;

  @override
  Future<void> signInWithOtp(String email) async {
    final client = _client;
    if (client == null) {
      throw Exception('Backend service is not configured. Please supply Supabase credentials.');
    }

    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }

    try {
      await client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: true,
      );
    } on AuthException catch (e) {
      throw _translateAuthException(e);
    } catch (_) {
      throw Exception('Unable to send verification code. Please try again.');
    }
  }

  @override
  Future<AuthResponse> verifyOtp(String email, String token) async {
    final client = _client;
    if (client == null) {
      throw Exception('Backend service is not configured. Please supply Supabase credentials.');
    }

    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();

    if (cleanToken.length < 6) {
      throw const FormatException('Verification code must be 6 digits.');
    }

    try {
      final response = await client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.email,
      );
      return response;
    } on AuthException catch (e) {
      throw _translateAuthException(e);
    } catch (_) {
      throw Exception(
        'Verification failed. The code may be invalid or expired.',
      );
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    final client = _client;
    if (client == null) {
      throw Exception('Backend service is not configured. Please supply Supabase credentials.');
    }

    try {
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'tripfam://login-callback',
      );
    } on AuthException catch (e) {
      throw _translateAuthException(e);
    } catch (_) {
      throw Exception(
        'Google sign-in could not be completed. Please try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {
      // Ignore sign out network failures; local session is cleared
    }
  }

  Exception _translateAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate') || msg.contains('too many')) {
      return Exception(
        'Too many attempts. Please wait a few minutes before trying again.',
      );
    }
    if (msg.contains('invalid') || msg.contains('expired')) {
      return Exception('The verification code is invalid or has expired.');
    }
    if (msg.contains('user not found')) {
      return Exception('No account found for this email address.');
    }
    return Exception(
      'Authentication error. Please check your details and try again.',
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  // Watch auth state changes stream to automatically update currentUser
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});
