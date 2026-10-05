import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus
        .authenticated, // Placeholder: authenticated for Phase 2 UI development
    this.userId,
    this.email,
  });

  final AuthStatus status;
  final String? userId;
  final String? email;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  void setAuthenticated({String? userId, String? email}) {
    state = AuthState(
      status: AuthStatus.authenticated,
      userId: userId,
      email: email,
    );
  }

  void signOut() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});
