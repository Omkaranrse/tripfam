import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/account/presentation/login_screen.dart';
import '../../features/account/presentation/onboarding_screen.dart';
import '../../features/account/presentation/privacy_policy_screen.dart';
import '../../features/account/presentation/profile_page.dart';
import '../../features/account/presentation/admin_verification_screen.dart';
import '../../features/account/presentation/terms_screen.dart';
import '../../features/account/presentation/verification_flow_screen.dart';
import '../../features/account/presentation/verification_status_screen.dart';
import '../../features/account/presentation/verify_otp_screen.dart';
import '../../features/chats/presentation/chat_conversation_screen.dart';
import '../../features/chats/presentation/chats_page.dart';
import '../../features/discover/presentation/discover_page.dart';
import '../../features/safety/presentation/safety_guide_screen.dart';
import '../../features/safety/presentation/safety_page.dart';
import '../../features/trips/presentation/my_trips_page.dart';
import '../../features/trips/domain/trip.dart';
import '../../features/trips/presentation/trip_detail_screen.dart';
import '../../features/trips/presentation/trip_form_screen.dart';
import '../../features/trips/presentation/trip_requests_screen.dart';
import '../presentation/app_navigation_shell.dart';
import '../presentation/not_found_page.dart';
import 'page_transitions.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/discover',
    errorBuilder: (context, state) => NotFoundPage(uri: state.uri.toString()),
    redirect: (context, state) {
      final path = state.matchedLocation;
      final isAuthRoute = path == '/login' || path == '/verify-otp';

      // Bypass authentication screens for UI evaluation
      if (isAuthRoute) {
        return '/discover';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) {
          final email = state.extra as String? ?? '';
          return VerifyOtpScreen(email: email);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        pageBuilder: (context, state) => SharedAxisPage(
          key: state.pageKey,
          child: const PrivacyPolicyScreen(),
        ),
      ),
      GoRoute(
        path: '/terms',
        pageBuilder: (context, state) =>
            SharedAxisPage(key: state.pageKey, child: const TermsScreen()),
      ),
      GoRoute(
        path: '/safety-guide',
        pageBuilder: (context, state) => SharedAxisPage(
          key: state.pageKey,
          child: const SafetyGuideScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (context, state) => SharedAxisPage(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/trip/new',
        pageBuilder: (context, state) =>
            SharedAxisPage(key: state.pageKey, child: const TripFormScreen()),
      ),
      GoRoute(
        path: '/trip/edit/:id',
        pageBuilder: (context, state) {
          final trip = state.extra as Trip?;
          return SharedAxisPage(
            key: state.pageKey,
            child: TripFormScreen(initialTrip: trip),
          );
        },
      ),
      GoRoute(
        path: '/trip/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return SharedAxisPage(
            key: state.pageKey,
            child: TripDetailScreen(tripId: id),
          );
        },
      ),
      GoRoute(
        path: '/trip/:id/requests',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return SharedAxisPage(
            key: state.pageKey,
            child: TripRequestsScreen(tripId: id),
          );
        },
      ),
      GoRoute(
        path: '/verification',
        pageBuilder: (context, state) => SharedAxisPage(
          key: state.pageKey,
          child: const VerificationStatusScreen(),
        ),
      ),
      GoRoute(
        path: '/verification/camera',
        pageBuilder: (context, state) => SharedAxisPage(
          key: state.pageKey,
          child: const VerificationFlowScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/verification',
        pageBuilder: (context, state) => SharedAxisPage(
          key: state.pageKey,
          child: const AdminVerificationScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                pageBuilder: (context, state) => FadeThroughPage(
                  key: state.pageKey,
                  child: const DiscoverPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-trips',
                pageBuilder: (context, state) => FadeThroughPage(
                  key: state.pageKey,
                  child: const MyTripsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                pageBuilder: (context, state) => FadeThroughPage(
                  key: state.pageKey,
                  child: const ChatsPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':tripId',
                    pageBuilder: (context, state) {
                      final tripId = state.pathParameters['tripId']!;
                      final extra = state.extra as Map<String, dynamic>?;
                      return SharedAxisPage(
                        key: state.pageKey,
                        child: ChatConversationScreen(
                          tripId: tripId,
                          tripTitle: extra?['title'] as String?,
                          destination: extra?['destination'] as String?,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/safety',
                pageBuilder: (context, state) => FadeThroughPage(
                  key: state.pageKey,
                  child: const SafetyPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => FadeThroughPage(
                  key: state.pageKey,
                  child: const ProfilePage(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
