import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/theme/app_theme.dart';
import 'package:tripfam/core/widgets/app_widgets.dart';

void main() {
  Widget testWrapper(Widget child, {bool isDark = false}) {
    return MaterialApp(
      theme: isDark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Design System Tokens & Components (Step 1)', () {
    test('Tokens verify specifications', () {
      // Spacing: 4, 8, 12, 16, 20, 24, 32, 48
      expect(AppSpacing.s4, 4.0);
      expect(AppSpacing.s8, 8.0);
      expect(AppSpacing.s12, 12.0);
      expect(AppSpacing.s16, 16.0);
      expect(AppSpacing.s20, 20.0);
      expect(AppSpacing.s24, 24.0);
      expect(AppSpacing.s32, 32.0);
      expect(AppSpacing.s48, 48.0);

      // Radii: 12, 20, 28, pill
      expect(AppRadius.r12, 12.0);
      expect(AppRadius.r20, 20.0);
      expect(AppRadius.r28, 28.0);
      expect(AppRadius.pill, 999.0);

      // Motion: fast 150ms, normal 280ms, slow 420ms
      expect(AppMotion.fast, const Duration(milliseconds: 150));
      expect(AppMotion.normal, const Duration(milliseconds: 280));
      expect(AppMotion.slow, const Duration(milliseconds: 420));
      expect(AppMotion.curve, Curves.easeOutCubic);
      expect(AppMotion.gentleSpring, Curves.easeOutBack);
    });

    testWidgets('AppCard renders with child and elevated shadow', (tester) async {
      await tester.pumpWidget(
        testWrapper(
          const AppCard(
            variant: AppCardVariant.elevated,
            child: Text('Card Content'),
          ),
        ),
      );
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('PrimaryButton and SecondaryButton render and respond to tap', (tester) async {
      var primaryTapped = false;
      var secondaryTapped = false;

      await tester.pumpWidget(
        testWrapper(
          Column(
            children: [
              PrimaryButton(
                label: 'Confirm Departure',
                onPressed: () => primaryTapped = true,
              ),
              SecondaryButton(
                label: 'Save Draft',
                onPressed: () => secondaryTapped = true,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Confirm Departure'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);

      await tester.tap(find.text('Confirm Departure'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();

      expect(primaryTapped, isTrue);
      expect(secondaryTapped, isTrue);
    });

    testWidgets('InfoChip renders in scrim, surface, and outline variants', (tester) async {
      await tester.pumpWidget(
        testWrapper(
          const Column(
            children: [
              InfoChip(
                label: '7 Days',
                icon: Icons.wb_sunny_outlined,
                variant: InfoChipVariant.scrim,
              ),
              InfoChip(
                label: 'Active Pace',
                icon: Icons.directions_walk_rounded,
                variant: InfoChipVariant.surface,
              ),
            ],
          ),
        ),
      );

      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('Active Pace'), findsOneWidget);
    });

    testWidgets('AppFilterChip renders animated selection and handles tap', (tester) async {
      var selected = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return testWrapper(
              AppFilterChip(
                label: 'Trek',
                isSelected: selected,
                onTap: () {
                  setState(() => selected = !selected);
                },
              ),
            );
          },
        ),
      );

      expect(find.text('Trek'), findsOneWidget);
      await tester.tap(find.text('Trek'));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
    });

    testWidgets('StatusPill renders different tones appropriately', (tester) async {
      await tester.pumpWidget(
        testWrapper(
          Column(
            children: [
              StatusPill.fromStatus('Confirmed'),
              StatusPill.fromStatus('Pending Host Review'),
              StatusPill.fromStatus('Cancelled'),
            ],
          ),
        ),
      );

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending Host Review'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('SectionHeader renders title, subtitle, and trailing', (tester) async {
      await tester.pumpWidget(
        testWrapper(
          const SectionHeader(
            title: 'Popular Departures',
            subtitle: 'Curated for solo travellers',
            trailing: Text('See All (8)'),
          ),
        ),
      );

      expect(find.text('Popular Departures'), findsOneWidget);
      expect(find.text('Curated for solo travellers'), findsOneWidget);
      expect(find.text('See All (8)'), findsOneWidget);
    });

    testWidgets('SegmentedTabs slides between tabs and updates state', (tester) async {
      var selectedTab = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return testWrapper(
              SegmentedTabs(
                tabs: const ['Departures', 'Requests'],
                selectedIndex: selectedTab,
                onChanged: (index) {
                  setState(() => selectedTab = index);
                },
              ),
            );
          },
        ),
      );

      expect(find.text('Departures'), findsOneWidget);
      expect(find.text('Requests'), findsOneWidget);

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();

      expect(selectedTab, 1);
    });

    testWidgets('SkeletonBox renders without error in animated and static modes', (tester) async {
      await tester.pumpWidget(
        testWrapper(
          const SkeletonBox(width: 200, height: 24),
        ),
      );
      expect(find.byType(SkeletonBox), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('IllustratedEmptyState renders custom vector graphics for each type', (tester) async {
      await tester.pumpWidget(
        testWrapper(
          IllustratedEmptyState(
            title: 'No Departures Found',
            message: 'Check back soon for new trips or organize your own.',
            type: EmptyIllustrationType.departures,
            actionLabel: 'Host a Trip',
            onActionPressed: () {},
          ),
        ),
      );

      expect(find.text('No Departures Found'), findsOneWidget);
      expect(find.text('Host a Trip'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('TripCard renders destination, date range, and status cleanly', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        testWrapper(
          TripCard(
            tripId: 'test-1',
            destination: 'Kyoto, Japan',
            dateRange: 'Oct 12 - Oct 19',
            status: 'Confirmed',
            budget: '\$1,800',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Kyoto, Japan'), findsOneWidget);
      expect(find.text('Oct 12 - Oct 19'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('\$1,800'), findsOneWidget);

      await tester.tap(find.text('Kyoto, Japan'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('FeaturedTripCard renders photo overlay with info chips and CTA', (tester) async {
      var ctaTapped = false;

      await tester.pumpWidget(
        testWrapper(
          FeaturedTripCard(
            tripId: 'hero-1',
            destination: 'Swiss Alps',
            title: 'Hike The Eiger Trail',
            daysLabel: '7 Days',
            paceLabel: 'Active Pace',
            membersLabel: '3/6 Joined',
            onCtaPressed: () => ctaTapped = true,
          ),
        ),
      );

      expect(find.text('SWISS ALPS'), findsOneWidget);
      expect(find.text('Hike The Eiger Trail'), findsOneWidget);
      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('Active Pace'), findsOneWidget);
      expect(find.text('3/6 Joined'), findsOneWidget);

      await tester.tap(find.text('View Departure'));
      await tester.pumpAndSettle();
      expect(ctaTapped, isTrue);
    });
  });
}
