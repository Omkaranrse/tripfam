import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';

class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _AppDestination(Icons.explore_outlined, Icons.explore, 'Discover'),
    _AppDestination(Icons.luggage_outlined, Icons.luggage, 'My trips'),
    _AppDestination(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chats'),
    _AppDestination(Icons.shield_outlined, Icons.shield, 'Safety'),
    _AppDestination(Icons.person_outline, Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = context.isCompact;
    final isExpanded = context.isExpanded;
    final isShort = context.isShort;
    final isDark = theme.brightness == Brightness.dark;

    final bottomDestinations = _destinations
        .map(
          (d) => NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
          ),
        )
        .toList();

    final railDestinations = _destinations
        .map(
          (d) => NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        title: Row(
          children: [
            // App icon using asset
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/AppIcon.png',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.travel_explore_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'TripMate',
              style: AppTypography.cardTitle.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
      body: Row(
        children: [
          if (!isCompact)
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: navigationShell.goBranch,
                      extended: isExpanded && !isShort,
                      labelType: isShort
                          ? NavigationRailLabelType.none
                          : (isExpanded ? null : NavigationRailLabelType.all),
                      leading: isExpanded && !isShort
                          ? Padding(
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 20,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Image.asset(
                                      'assets/images/AppIcon.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.explore_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'TripMate',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      destinations: railDestinations,
                    ),
                  ),
                ),
              ),
            ),
          if (!isCompact)
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.colorScheme.outline.withAlpha(100),
            ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: isCompact ? false : true,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.maxContentWidth,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 0 : 24,
                      vertical: isCompact ? 0 : 12,
                    ),
                    child: navigationShell,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isCompact
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkForestSurfaceDark
                        : AppTheme.darkForestSurfaceLight,
                    borderRadius: AppRadius.borderPill,
                    border: Border.all(
                      color: Colors.white.withAlpha(25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 80 : 45),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.borderPill,
                    child: NavigationBar(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: navigationShell.goBranch,
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysHide,
                      height: 60,
                      destinations: bottomDestinations,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _AppDestination {
  const _AppDestination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
