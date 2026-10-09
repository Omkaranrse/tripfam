import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/theme/app_theme.dart';
import 'package:tripfam/core/widgets/app_widgets.dart';

void main() {
  group('Glassmorphism System Tests', () {
    tearDown(() {
      GlassConfig.enabled = true;
    });

    testWidgets('GlassTheme resolves tokens for light theme', (tester) async {
      late GlassTheme lightExt;

      await tester.pumpWidget(
        Theme(
          data: AppTheme.light,
          child: Builder(
            builder: (context) {
              lightExt = GlassTheme.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(lightExt.tintColor, equals(GlassTheme.light.tintColor));
      expect(lightExt.borderColor, equals(GlassTheme.light.borderColor));
      expect(lightExt.fallbackColor, equals(GlassTheme.light.fallbackColor));
    });

    testWidgets('GlassContainer renders BackdropFilter when blur is active', (tester) async {
      GlassConfig.enabled = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: GlassContainer(
              child: Text('Glass content'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(find.text('Glass content'), findsOneWidget);
    });

    testWidgets('GlassContainer falls back without BackdropFilter when GlassConfig.enabled is false', (tester) async {
      GlassConfig.enabled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: GlassContainer(
              child: Text('Fallback content'),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Fallback content'), findsOneWidget);
    });

    testWidgets('GlassContainer disables BackdropFilter when disableAnimations is true', (tester) async {
      GlassConfig.enabled = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: GlassContainer(
                child: Text('Reduced motion glass'),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.text('Reduced motion glass'), findsOneWidget);
    });

    testWidgets('GlassIconButton provides 48x48dp target, tooltip and semantics', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: GlassIconButton(
                icon: Icons.favorite_rounded,
                tooltip: 'Favorite trip',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final buttonFinder = find.byType(GlassIconButton);
      expect(buttonFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(buttonFinder);
      expect(renderBox.size.width, greaterThanOrEqualTo(48.0));
      expect(renderBox.size.height, greaterThanOrEqualTo(48.0));

      await tester.tap(buttonFinder);
      expect(tapped, isTrue);

      expect(find.byTooltip('Favorite trip'), findsOneWidget);
    });

    testWidgets('InfoChip renders correctly with InfoChipVariant.glass', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: InfoChip(
              variant: InfoChipVariant.glass,
              icon: Icons.wb_sunny_outlined,
              label: '3 Days',
            ),
          ),
        ),
      );

      expect(find.byType(GlassContainer), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    });
  });
}
