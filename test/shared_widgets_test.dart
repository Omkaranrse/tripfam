import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/errors/app_error_handler.dart';
import 'package:tripfam/core/widgets/app_widgets.dart';

void main() {
  testWidgets('AppButton renders label and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Join Adventure',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Join Adventure'), findsOneWidget);
    await tester.tap(find.text('Join Adventure'));
    expect(tapped, isTrue);
  });

  testWidgets('AppButton does not trigger tap when isLoading is true', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Processing',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Processing'));
    expect(tapped, isFalse);
  });

  testWidgets('AppTextField toggles password visibility', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppTextField(label: 'Password', isPassword: true)),
      ),
    );

    expect(find.text('Password'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('ErrorView masks raw exception with safe friendly message', (
    tester,
  ) async {
    final rawError = Exception('FATAL SQL 42501: leaked internal table schema');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ErrorView(error: rawError)),
      ),
    );

    // Raw exception details must NOT be displayed to the user
    expect(find.textContaining('FATAL SQL'), findsNothing);
    expect(find.textContaining('leaked internal'), findsNothing);

    // Safe user-friendly message must be displayed
    final safeText = AppErrorHandler.safeMessage(rawError);
    expect(find.text(safeText), findsOneWidget);
  });

  testWidgets('EmptyState displays action button and triggers callback', (
    tester,
  ) async {
    var actionTriggered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'No Items',
            message: 'Nothing to display here yet.',
            actionLabel: 'Create New',
            onActionPressed: () => actionTriggered = true,
          ),
        ),
      ),
    );

    expect(find.text('No Items'), findsOneWidget);
    expect(find.text('Create New'), findsOneWidget);

    await tester.tap(find.text('Create New'));
    expect(actionTriggered, isTrue);
  });
}
