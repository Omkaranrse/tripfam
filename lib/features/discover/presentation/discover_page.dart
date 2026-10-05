import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../account/data/auth_repository.dart';
import '../../account/data/profile_repository.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_filter.dart';
import 'trip_filter_sheet.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  String _selectedCategory = 'All';
  String _selectedDateFilter = 'Anytime';

  static const _categories = ['All', 'Trek', 'Beach', 'Road trip', 'City'];
  static const _dateFilters = [
    'Anytime',
    'This weekend',
    'Next 7 days',
    'Next month',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (_scrollController.hasClients) {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _showFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const TripFilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(discoverTripsProvider);
    final activeFilter = ref.watch(tripFilterProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final isVerifiedViewer =
        currentUser != null && userProfile?.isVerified == true;

    final theme = Theme.of(context);
    final isCompact = context.isCompact;

    final displayName =
        userProfile?.displayName.trim().isNotEmpty == true
            ? userProfile!.displayName.trim().split(' ').first
            : 'Explorer';
    final hasCity = userProfile?.homeCity?.trim().isNotEmpty == true;
    final userCity = hasCity ? userProfile!.homeCity!.trim() : 'Set your city';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'discover_host_trip_fab',
        onPressed: () => context.push('/trip/new'),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Host Trip'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(discoverTripsProvider.future),
        child: tripsAsync.when(
          data: (trips) {
            // Apply category filter in-memory if selected
            var filteredTrips = trips;
            if (_selectedCategory != 'All') {
              final cat = _selectedCategory.toLowerCase();
              filteredTrips = filteredTrips.where((t) {
                final matchTag =
                    t.tags.any((tag) => tag.toLowerCase().contains(cat));
                final matchDest =
                    t.destination.toLowerCase().contains(cat);
                return matchTag || matchDest;
              }).toList();
            }

            final featuredTrip =
                filteredTrips.isNotEmpty ? filteredTrips.first : null;
            final popularTrips = filteredTrips.length > 1
                ? filteredTrips.sublist(1)
                : (filteredTrips.isNotEmpty
                    ? [filteredTrips.first]
                    : <Trip>[]);

            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = isCompact
                    ? 1
                    : (width >= 1000 ? 3 : (width >= 640 ? 2 : 1));
                const gap = 16.0;
                final cardWidth = columns == 1
                    ? width
                    : (width - (gap * (columns - 1))) / columns;

                return ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.pagePaddingInsets(
                    context,
                    vertical: AppSpacing.s8,
                  ),
                  children: [
                    // 1. Greeting & City Chip Row
                    _GreetingRow(
                      displayName: displayName,
                      userCity: userCity,
                      hasCity: hasCity,
                    ).animateEntrance(context: context, index: 0),
                    const SizedBox(height: AppSpacing.s16),

                    // 2. Large Display Headline
                    Text(
                      'Discover Trips',
                      style: AppTypography.display.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ).animateEntrance(context: context, index: 1),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Find your next adventure with like-minded travellers',
                      style: AppTypography.body.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(130),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // 3. Search Button / Bar
                    _SearchRow(
                      searchController: _searchController,
                      activeFilter: activeFilter,
                      onFilterTap: _showFilterModal,
                      ref: ref,
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // 4. Horizontally Scrolling Category Chip Row
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.s8),
                        itemBuilder: (context, i) {
                          final category = _categories[i];
                          final isSelected = _selectedCategory == category;
                          return _AnimatedPillChip(
                            label: category,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() => _selectedCategory = category);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // 5. Featured Trip Hero Card
                    if (featuredTrip != null) ...[
                      _FeaturedHeroCard(
                        trip: featuredTrip,
                        scrollOffset: _scrollOffset,
                      ).animateEntrance(context: context, index: 2),
                      const SizedBox(height: AppSpacing.s24),
                    ],

                    // 6. "Popular" Section Header & Horizontal Date Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Popular',
                              style: AppTypography.titleStyle(context)
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${filteredTrips.length} available',
                              style: AppTypography.caption.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withAlpha(130),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Horizontal Date Chips
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _dateFilters.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.s8),
                        itemBuilder: (context, i) {
                          final dateFilter = _dateFilters[i];
                          final isSelected =
                              _selectedDateFilter == dateFilter;
                          return _AnimatedPillChip(
                            label: dateFilter,
                            isSelected: isSelected,
                            small: true,
                            onTap: () {
                              setState(
                                () => _selectedDateFilter = dateFilter,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // Popular List (Dark-forest cards)
                    if (popularTrips.isEmpty)
                      EmptyState(
                        title: 'No matching trips found',
                        message: activeFilter.isActive ||
                                _selectedCategory != 'All'
                            ? 'Try adjusting your filters or destination keywords.'
                            : 'Explore our safety guide and travel tips while new departures are posted!',
                        icon: Icons.travel_explore_rounded,
                        actionLabel: activeFilter.isActive
                            ? 'Reset Filters'
                            : 'Explore Safety Guide',
                        onActionPressed: () {
                          if (activeFilter.isActive) {
                            _searchController.clear();
                            setState(() {
                              _selectedCategory = 'All';
                              _selectedDateFilter = 'Anytime';
                            });
                            ref.read(tripFilterProvider.notifier).state =
                                const TripFilter();
                          } else {
                            context.push('/safety/guide');
                          }
                        },
                      )
                    else
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (var i = 0; i < popularTrips.length; i++)
                            SizedBox(
                              width: cardWidth,
                              child: _DarkForestTripCard(
                                trip: popularTrips[i],
                                isVerifiedViewer: isVerifiedViewer,
                              ).animateEntrance(
                                context: context,
                                index: i + 3,
                                maxAnimatedItems: 12,
                              ),
                            ),
                        ],
                      ),
                    // Space for floating bottom pill nav
                    const SizedBox(height: 100),
                  ],
                );
              },
            );
          },
          loading: () => const _DiscoverLoadingSkeleton(),
          error: (error, _) => ErrorView(
            error: error,
            onRetry: () => ref.refresh(discoverTripsProvider),
          ),
        ),
      ),
    );
  }
}

// ─── Greeting Row ────────────────────────────────────────────────────────────

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({
    required this.displayName,
    required this.userCity,
    required this.hasCity,
  });

  final String displayName;
  final String userCity;
  final bool hasCity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Hi, $displayName 👋',
            style: AppTypography.titleStyle(context).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        InkWell(
          onTap: hasCity ? null : () => context.push('/profile/edit'),
          borderRadius: AppRadius.borderPill,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(160),
              borderRadius: AppRadius.borderPill,
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha(60),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasCity
                      ? Icons.location_on_rounded
                      : Icons.add_location_alt_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  userCity,
                  style: AppTypography.captionStyle(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: hasCity ? null : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Search Row ──────────────────────────────────────────────────────────────

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.searchController,
    required this.activeFilter,
    required this.onFilterTap,
    required this.ref,
  });

  final TextEditingController searchController;
  final TripFilter activeFilter;
  final VoidCallback onFilterTap;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            onChanged: (val) {
              ref.read(tripFilterProvider.notifier).update(
                    (s) => s.copyWith(destinationQuery: val),
                  );
            },
            decoration: InputDecoration(
              hintText: 'Search destinations…',
              hintStyle: AppTypography.body.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        searchController.clear();
                        ref.read(tripFilterProvider.notifier).update(
                              (s) => s.copyWith(destinationQuery: ''),
                            );
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.borderPill,
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(80),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.borderPill,
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha(80),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Badge(
          isLabelVisible: activeFilter.isActive,
          child: InkWell(
            onTap: onFilterTap,
            borderRadius: AppRadius.borderPill,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeFilter.isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(80),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: activeFilter.isActive
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Animated Pill Chip ──────────────────────────────────────────────────────

class _AnimatedPillChip extends StatelessWidget {
  const _AnimatedPillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.small = false,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = theme.colorScheme.primary;
    final unselectedBg = isDark
        ? Colors.white.withAlpha(16)
        : theme.colorScheme.surfaceContainerHighest.withAlpha(110);

    final selectedTextColor = theme.colorScheme.onPrimary;
    final unselectedTextColor = theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderPill,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: small ? 14 : 18,
            vertical: small ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: AppRadius.borderPill,
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : theme.colorScheme.outline.withAlpha(60),
            ),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: small ? 12 : 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? selectedTextColor : unselectedTextColor,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Featured Trip Hero Card ─────────────────────────────────────────────────

class _FeaturedHeroCard extends StatefulWidget {
  const _FeaturedHeroCard({
    required this.trip,
    required this.scrollOffset,
  });

  final Trip trip;
  final double scrollOffset;

  @override
  State<_FeaturedHeroCard> createState() => _FeaturedHeroCardState();
}

class _FeaturedHeroCardState extends State<_FeaturedHeroCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    // Subtle parallax translation
    final parallaxOffset = disableAnimations
        ? 0.0
        : (widget.scrollOffset * 0.10).clamp(-16.0, 16.0);

    return AnimatedScale(
      scale: _isPressed && !disableAnimations ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.border24,
          boxShadow: AppShadows.floating(context),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.border24,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(
                '/trip/${widget.trip.id}',
                extra: widget.trip,
              ),
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  // Full-bleed photo with subtle parallax
                  Transform.translate(
                    offset: Offset(0, parallaxOffset),
                    child: DestinationImage(
                      tripId: widget.trip.id,
                      destination: widget.trip.destination,
                      aspectRatio: 16 / 11,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),

                  // Dark bottom scrim (contrast >= 4.5:1)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(50),
                            Colors.black.withAlpha(220),
                          ],
                          stops: const [0.3, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Overlay Content
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Uppercase destination label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: AppRadius.borderPill,
                          ),
                          child: Text(
                            widget.trip.destination.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),

                        // Title
                        Text(
                          widget.trip.destination,
                          style: AppTypography.headline.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.s4),

                        // Description snippet
                        Text(
                          widget.trip.description,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withAlpha(200),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        // Info Chips
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _HeroInfoChip(
                              icon: Icons.wb_sunny_outlined,
                              label: '${widget.trip.durationDays} Days',
                            ),
                            _HeroInfoChip(
                              icon: Icons.directions_walk_rounded,
                              label: (widget.trip
                                          .hostTravelStyle['pace']
                                          ?.toString() ??
                                      'Moderate')
                                  .split('(')
                                  .first
                                  .trim(),
                            ),
                            _HeroInfoChip(
                              icon: Icons.group_outlined,
                              label:
                                  '${widget.trip.confirmedMembersCount}/${widget.trip.maxMembers}',
                            ),
                            if (widget.trip.budget != null)
                              _HeroInfoChip(
                                icon: Icons.payments_outlined,
                                label: '\$${widget.trip.budget!.toInt()}',
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Primary Pill Button
                        AppButton(
                          label: 'Explore Adventure',
                          icon: Icons.arrow_forward_rounded,
                          isPill: true,
                          isFullWidth: true,
                          onPressed: () => context.push(
                            '/trip/${widget.trip.id}',
                            extra: widget.trip,
                          ),
                          variant: AppButtonVariant.primary,
                          size: AppButtonSize.medium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Info Chip ──────────────────────────────────────────────────────────

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(90),
        borderRadius: AppRadius.borderPill,
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.lime),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dark Forest Trip Card ───────────────────────────────────────────────────

class _DarkForestTripCard extends StatefulWidget {
  const _DarkForestTripCard({
    required this.trip,
    required this.isVerifiedViewer,
  });

  final Trip trip;
  final bool isVerifiedViewer;

  @override
  State<_DarkForestTripCard> createState() => _DarkForestTripCardState();
}

class _DarkForestTripCardState extends State<_DarkForestTripCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final cardBg = AppTheme.darkForest(context);

    final dateStr =
        '${widget.trip.startDate.day}/${widget.trip.startDate.month} – ${widget.trip.endDate.day}/${widget.trip.endDate.month}';

    return AnimatedScale(
      scale: _isPressed && !disableAnimations ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: AppRadius.border20,
          border: Border.all(
            color: Colors.white.withAlpha(20),
            width: 1,
          ),
          boxShadow: AppShadows.subtle(context),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.border20,
          child: InkWell(
            onTap: () => context.push(
              '/trip/${widget.trip.id}',
              extra: widget.trip,
            ),
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: AppRadius.border20,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  // Photo Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: DestinationImage(
                        tripId: 'popular-${widget.trip.id}',
                        destination: widget.trip.destination,
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        aspectRatio: 1.0,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dates
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: AppTheme.lime,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: const TextStyle(
                                  color: AppTheme.lime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Destination title
                        Text(
                          widget.trip.destination,
                          style: AppTypography.cardTitle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Tags row
                        if (widget.trip.tags.isNotEmpty)
                          Text(
                            widget.trip.tags.take(2).join(' · '),
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withAlpha(140),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),

                        // Avatar Stack & Member info
                        AvatarStack(
                          totalMembers: widget.trip.confirmedMembersCount,
                          isVerifiedViewer: widget.isVerifiedViewer,
                          avatarUrls: widget.trip.hostAvatarPath != null
                              ? [widget.trip.hostAvatarPath]
                              : [],
                          borderColor: cardBg,
                          textColor: Colors.white70,
                          avatarSize: 22,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),

                  // Circular Arrow Button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.lime.withAlpha(40),
                      border: Border.all(
                        color: AppTheme.lime,
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppTheme.lime,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading Skeleton ────────────────────────────────────────────────────────

class _DiscoverLoadingSkeleton extends StatelessWidget {
  const _DiscoverLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.pagePaddingInsets(context, vertical: AppSpacing.s8),
      children: [
        // Greeting skeleton
        const SkeletonBox(width: 140, height: 22),
        const SizedBox(height: AppSpacing.s16),
        // Headline skeleton
        const SkeletonBox(width: 200, height: 32),
        const SizedBox(height: AppSpacing.s8),
        const SkeletonBox(width: 280, height: 14),
        const SizedBox(height: AppSpacing.s16),
        // Search bar skeleton
        const SkeletonBox(height: 48, borderRadiusValue: 24),
        const SizedBox(height: AppSpacing.s16),
        // Chips skeleton
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SkeletonBox(
                  width: 72,
                  height: 36,
                  borderRadiusValue: AppRadius.pill,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s20),
        // Hero card skeleton
        const SkeletonBox(height: 260, borderRadiusValue: 24),
        const SizedBox(height: AppSpacing.s24),
        // Section header skeleton
        const SkeletonBox(width: 100, height: 20),
        const SizedBox(height: AppSpacing.s16),
        // Popular rows skeleton
        for (var i = 0; i < 4; i++)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.s12),
            child: SkeletonBox(height: 96, borderRadiusValue: AppRadius.r20),
          ),
      ],
    );
  }
}
