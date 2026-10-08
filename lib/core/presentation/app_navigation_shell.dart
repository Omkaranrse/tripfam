import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../layout/breakpoints.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

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

    final List<Widget> bottomDestinations = _destinations
        .map<Widget>(
          (d) => NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: d.label,
          ),
        )
        .toList();

    final List<NavigationRailDestination> railDestinations = _destinations
        .map<NavigationRailDestination>(
          (d) => NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
        )
        .toList();

    final location = GoRouterState.of(context).matchedLocation;
    final isInsideChatRoom =
        location.startsWith('/chats/') && location != '/chats';

    return Scaffold(
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
              top: isCompact,
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
      bottomNavigationBar: (isCompact && !isInsideChatRoom)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: GlassContainer(
                  borderRadius: AppRadius.borderPill,
                  blur: 20.0,
                  tintColor: isDark
                      ? const Color(0xF2101C15)
                      : const Color(0xF5132219),
                  borderColor: Colors.white.withAlpha(isDark ? 30 : 40),
                  borderWidth: 1.0,
                  showTopHighlight: true,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 100 : 65),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      height: 60,
                      indicatorColor: const Color(0xFFC6E062),
                      indicatorShape: const StadiumBorder(),
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysHide,
                      iconTheme: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const IconThemeData(
                            color: Color(0xFF132219),
                            size: 24,
                          );
                        }
                        return IconThemeData(
                          color: Colors.white.withAlpha(210),
                          size: 24,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: (index) {
                        HapticFeedback.selectionClick();
                        navigationShell.goBranch(index);
                      },
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
