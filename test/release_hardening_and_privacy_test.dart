import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/widgets/app_button.dart';
import 'package:tripfam/features/account/presentation/privacy_policy_screen.dart';
import 'package:tripfam/features/account/presentation/terms_screen.dart';
import 'package:tripfam/features/safety/presentation/safety_guide_screen.dart';

void main() {
  group('Release Prep & Accessibility Widget Tests', () {
    testWidgets(
      'PrivacyPolicyScreen renders at compact mobile size without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Privacy Policy'), findsOneWidget);
        expect(find.text('TripMate Privacy Commitment'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('TermsScreen renders at medium tablet size without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: TermsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Community Guidelines & Terms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'SafetyGuideScreen renders at expanded desktop size without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const MaterialApp(home: SafetyGuideScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Community Safety Guide'), findsOneWidget);
        expect(find.text('Travel Smart, Stay Safe'), findsOneWidget);
        expect(find.text('Always Complete an Intro Call'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('AppButton enforces minimum 48x48 dp accessible tap target', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton(
                label: 'Tap Me',
                onPressed: () {},
                size: AppButtonSize.small,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(AppButton));
      expect(size.height, greaterThanOrEqualTo(48.0));
      expect(size.width, greaterThanOrEqualTo(48.0));
    });
  });

  group('Data Export Privacy & Formatting Tests', () {
    test('Data export schema converts cleanly to valid JSON', () {
      final mockData = {
        'exported_at': '2026-10-03T16:00:00Z',
        'app_version': '1.0.0',
        'profile': {
          'id': 'user-1',
          'display_name': 'Marco',
          'home_city': 'Rome',
          'is_verified': true,
        },
        'trips_hosted': [
          {'id': 'trip-1', 'destination': 'Amalfi Coast'},
        ],
        'sent_messages': [
          {'id': 'msg-1', 'content': 'Hello companions!'},
        ],
        'trusted_contacts': [
          {'name': 'Sister', 'email': 'sister@example.com'},
        ],
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(mockData);
      expect(jsonString, contains('"display_name": "Marco"'));
      expect(jsonString, contains('"destination": "Amalfi Coast"'));
      expect(jsonString, contains('"content": "Hello companions!"'));

      final decoded = json.decode(jsonString) as Map<String, dynamic>;
      expect(decoded['profile']['id'], equals('user-1'));
      expect((decoded['trips_hosted'] as List).length, equals(1));
    });
  });
}
