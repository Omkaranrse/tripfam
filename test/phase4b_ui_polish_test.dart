import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripfam/core/config/app_config.dart';
import 'package:tripfam/core/providers/app_providers.dart';
import 'package:tripfam/core/theme/app_theme.dart';
import 'package:tripfam/core/widgets/app_widgets.dart';
import 'package:tripfam/features/account/data/auth_repository.dart';
import 'package:tripfam/features/account/data/profile_repository.dart';
import 'package:tripfam/features/account/domain/user_profile.dart';
import 'package:tripfam/features/account/presentation/profile_page.dart';
import 'package:tripfam/features/discover/presentation/discover_page.dart';
import 'package:tripfam/features/safety/data/safety_repository.dart';
import 'package:tripfam/features/safety/presentation/safety_page.dart';
import 'package:tripfam/features/trips/data/join_request_repository.dart';
import 'package:tripfam/features/trips/data/trip_repository.dart';
import 'package:tripfam/features/trips/domain/join_request.dart';
import 'package:tripfam/features/trips/domain/trip.dart';
import 'package:tripfam/features/trips/domain/trip_filter.dart';
import 'package:tripfam/features/trips/presentation/my_trips_page.dart';
import 'package:tripfam/features/trips/presentation/trip_detail_screen.dart';

class _MockUserProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async {
    return const UserProfile(
      id: 'test-user',
      displayName: 'Maya Adventurer',
      homeCity: 'Kyoto, Japan',
      bio: 'Lover of mountain trails and street food adventures.',
      isVerified: true,
      travelStyle: {
        'pace': 'Active & Fast',
        'budget': 'Mid-range',
        'earlyBird': 'Early riser',
      },
    );
  }
}

final _testTrip = Trip(
  id: 'trip-101',
  hostId: 'host-001',
  destination: 'Kyoto & Osaka, Japan',
  startDate: DateTime(2026, 10, 10),
  endDate: DateTime(2026, 10, 18),
  maxMembers: 6,
  description: 'Immerse in ancient shrines, bamboo groves, and delicious ramen stalls across Kansai.',
  budget: 1800.0,
  tags: const ['Culture', 'Foodie', 'Walking'],
  requiresVerifiedMembers: true,
  createdAt: DateTime(2026, 10, 1),
  hostDisplayName: 'Kenji Sato',
  hostIsVerified: true,
  hostTravelStyle: const {'pace': 'Active & Fast', 'budget': 'Mid-range'},
  confirmedMembersCount: 2,
);

class _MockTripRepo extends Fake implements TripRepository {
  @override
  Future<Trip?> getTripById(String id) async => _testTrip;

  @override
  Future<List<Trip>> getDiscoverTrips({TripFilter? filter, int limit = 20, int offset = 0}) async => [_testTrip];

  @override
  Future<bool> hasRequestedToJoin(String tripId) async => false;

  @override
  Future<bool> isTripMember(String tripId) async => false;
}

class _MockJoinRequestRepo extends Fake implements JoinRequestRepository {
  @override
  Future<JoinRequest?> getRequestForTrip(String tripId) async => null;

  @override
  Future<List<JoinRequest>> getTripJoinRequests(String tripId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4B Design Tokens Verification', () {
    test('Spacing tokens match specification: 4, 8, 12, 16, 24, 32', () {
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);
    });

    test('Radius token matches specification: 12', () {
      expect(AppRadius.r12, 12.0);
      expect(AppRadius.radius12, const Radius.circular(12.0));
      expect(AppRadius.border12, BorderRadius.circular(12.0));
    });

    test('Motion tokens match specification: fast 150ms, normal 280ms, slow 420ms, easeOutCubic', () {
      expect(AppMotion.fast, const Duration(milliseconds: 150));
      expect(AppMotion.normal, const Duration(milliseconds: 280));
      expect(AppMotion.slow, const Duration(milliseconds: 420));
      expect(AppMotion.curve, Curves.easeOutCubic);
      expect(AppMotion.gentleSpring, Curves.easeOutBack);
    });

    test('Poppins type scale matches specification', () {
      // headline 28/600
      expect(AppTypography.headline.fontSize, 28);
      expect(AppTypography.headline.fontWeight, FontWeight.w600);
      expect(AppTypography.headline.fontFamily, 'Poppins');

      // title 20/600
      expect(AppTypography.title.fontSize, 20);
      expect(AppTypography.title.fontWeight, FontWeight.w600);
      expect(AppTypography.title.fontFamily, 'Poppins');

      // card title 16/500
      expect(AppTypography.cardTitle.fontSize, 16);
      expect(AppTypography.cardTitle.fontWeight, FontWeight.w500);
      expect(AppTypography.cardTitle.fontFamily, 'Poppins');

      // body 14/400
      expect(AppTypography.body.fontSize, 14);
      expect(AppTypography.body.fontWeight, FontWeight.w400);
      expect(AppTypography.body.fontFamily, 'Poppins');

      // caption 12/400
      expect(AppTypography.caption.fontSize, 12);
      expect(AppTypography.caption.fontWeight, FontWeight.w400);
      expect(AppTypography.caption.fontFamily, 'Poppins');
    });

    test('AppTheme incorporates tokens in both light and dark modes', () {
      final light = AppTheme.light;
      final dark = AppTheme.dark;

      expect(light.textTheme.headlineMedium?.fontSize, 28);
      expect(dark.textTheme.headlineMedium?.fontSize, 28);
      expect(light.textTheme.titleMedium?.fontSize, 16);
      expect(dark.textTheme.titleMedium?.fontSize, 16);
      expect(light.textTheme.bodyMedium?.fontSize, 14);
      expect(dark.textTheme.bodyMedium?.fontSize, 14);
      expect(light.textTheme.bodySmall?.fontSize, 12);
      expect(dark.textTheme.bodySmall?.fontSize, 12);

      expect(light.cardTheme.shape, isA<RoundedRectangleBorder>());
      final lightBorder = light.cardTheme.shape as RoundedRectangleBorder;
      expect(lightBorder.borderRadius, AppRadius.border12);
    });
  });

  group('Phase 4B Screen Layout Responsiveness & Text Scaling Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildTestScreen(
      Widget screen, {
      double textScale = 1.0,
      bool isDark = false,
    }) {
      return ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(url: '', anonKey: ''),
          ),
          supabaseReadyProvider.overrideWithValue(false),
          sharedPreferencesProvider.overrideWithValue(prefs),
          userProfileProvider.overrideWith(_MockUserProfileNotifier.new),
          currentUserProvider.overrideWithValue(null),
          tripRepositoryProvider.overrideWithValue(_MockTripRepo()),
          joinRequestRepositoryProvider.overrideWithValue(
            _MockJoinRequestRepo(),
          ),
          userTripRequestProvider.overrideWith((ref, id) async => null),
          tripJoinRequestsProvider.overrideWith((ref, id) async => []),
          discoverTripsProvider.overrideWith((ref) async => [_testTrip]),
          myTripsProvider.overrideWith((ref) async => [_testTrip]),
          myJoinRequestsProvider.overrideWith((ref) async => []),
          trustedContactsProvider.overrideWith((ref) async => []),
          blockedUsersListProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: isDark ? AppTheme.dark : AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: screen,
            ),
          ),
        ),
      );
    }

    const testWidths = [400.0, 800.0, 1400.0];

    for (final width in testWidths) {
      testWidgets(
        'DiscoverPage renders at ${width.toInt()}px without overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestScreen(const DiscoverPage()));
          await tester.pumpAndSettle();

          expect(find.text('Discover Trips'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'TripDetailScreen renders at ${width.toInt()}px with sticky bottom bar and redesign elements',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestScreen(const TripDetailScreen(tripId: 'trip-101')),
          );
          await tester.pumpAndSettle();

          expect(find.text('KYOTO & OSAKA, JAPAN'), findsOneWidget);
          expect(find.text('Kyoto & Osaka, Japan'), findsWidgets);
          expect(find.text('Meeting Point & Departure'), findsOneWidget);
          expect(find.text('Trip Members'), findsOneWidget);
          expect(find.byType(AvatarStack), findsOneWidget);
          expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
          expect(find.text('Request to Join Adventure'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'ProfilePage renders at ${width.toInt()}px without overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestScreen(const ProfilePage()));
          await tester.pumpAndSettle();

          expect(find.text('Profile & Settings'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'SafetyPage renders at ${width.toInt()}px without overflow and displays Check-In',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestScreen(const SafetyPage()));
          await tester.pumpAndSettle();

          expect(find.text('Safety Center'), findsOneWidget);
          expect(find.text('Safety Check-In'), findsOneWidget);
          expect(find.text('Trusted Contacts'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'MyTripsPage renders at ${width.toInt()}px with Departures and Requests segmented control',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestScreen(const MyTripsPage()));
          await tester.pumpAndSettle();

          expect(find.text('My Trips'), findsOneWidget);
          expect(find.text('Departures'), findsOneWidget);
          expect(find.text('Requests'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

    }

    testWidgets(
      'Discover, TripDetail and Profile render cleanly at 1.5x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Discover at 1.5x
        await tester.pumpWidget(
          buildTestScreen(const DiscoverPage(), textScale: 1.5),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Trip detail at 1.5x
        await tester.pumpWidget(
          buildTestScreen(
            const TripDetailScreen(tripId: 'trip-101'),
            textScale: 1.5,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Profile at 1.5x
        await tester.pumpWidget(
          buildTestScreen(const ProfilePage(), textScale: 1.5),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Also verify all 3 in dark mode at 1.5x text scale
        await tester.pumpWidget(
          buildTestScreen(const DiscoverPage(), textScale: 1.5, isDark: true),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          buildTestScreen(
            const TripDetailScreen(tripId: 'trip-101'),
            textScale: 1.5,
            isDark: true,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          buildTestScreen(const ProfilePage(), textScale: 1.5, isDark: true),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final width in testWidths) {
      testWidgets(
        'Screens render in dark mode at ${width.toInt()}px without overflow',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            buildTestScreen(const DiscoverPage(), isDark: true),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            buildTestScreen(
              const TripDetailScreen(tripId: 'trip-101'),
              isDark: true,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            buildTestScreen(const ProfilePage(), isDark: true),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Motion and entrance animations respect MediaQuery.disableAnimations',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  return const Text('Test Animation Respect')
                      .animateEntrance(context: context, index: 0);
                },
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Test Animation Respect'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
