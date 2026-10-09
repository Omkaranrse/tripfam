import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tripfam/core/config/app_config.dart';
import 'package:tripfam/core/providers/app_providers.dart';
import 'package:tripfam/core/theme/app.dart';
import 'package:tripfam/features/account/data/profile_repository.dart';
import 'package:tripfam/features/account/domain/user_profile.dart';

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async {
    return const UserProfile(
      id: 'test-user',
      displayName: 'Test Explorer',
      homeCity: 'Paris',
      travelStyle: {'pace': 'Moderate'},
    );
  }
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  Widget createApp() => ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(url: '', anonKey: ''),
      ),
      supabaseReadyProvider.overrideWithValue(false),
      sharedPreferencesProvider.overrideWithValue(preferences),
      userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
    ],
    child: const TripMateApp(),
  );

  testWidgets(
    'compact mobile navigation renders Discover and navigates without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.text('Discover Trips'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.luggage_outlined));
      await tester.pumpAndSettle();

      expect(find.text('My Trips'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('medium tablet layout uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'expanded desktop layout (1400px) uses extended rail without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Discover Trips'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rail remains usable on a short viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app uses light theme exclusively on profile page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('Profile'))).brightness,
      Brightness.light,
    );
  });
}
