import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../account/data/profile_repository.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/widgets/join_request_form_sheet.dart';
import '../domain/deck_config.dart';
import 'controllers/deck_controller.dart';
import 'trip_filter_sheet.dart';
import 'widgets/swipeable_deck.dart';
import 'widgets/upcoming_trips_strip.dart';

class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final _searchController = TextEditingController();
  final _deckKey = GlobalKey<SwipeableDeckState>();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showFilterModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) => const TripFilterSheet(),
    );
  }

  void _openTripDetails(Trip trip) {
    JoinRequestFormSheet.show(context, trip);
  }

  Future<void> _handleSwipe(SwipeDirection direction) async {
    await ref.read(deckControllerProvider.notifier).swipe(direction);
  }

  Future<void> _handleUndo() async {
    await ref.read(deckControllerProvider.notifier).undo();
  }

  @override
  Widget build(BuildContext context) {
    final deckState = ref.watch(deckControllerProvider);
    final userProfile = ref.watch(userProfileProvider).value;
    final savedTripsAsync = ref.watch(savedTripsProvider);
    final savedCount = savedTripsAsync.value?.length ?? deckState.savedTripIds.length;

    final theme = Theme.of(context);

    final displayName = userProfile?.displayName.trim().isNotEmpty == true
        ? userProfile!.displayName.trim().split(' ').first
        : 'Explorer';

    // Responsive deck sizing: Proportioned to gracefully fill the mobile viewport
    // without overflowing or leaving awkward dead voids above the floating bottom dock.
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final deckWidth = (screenWidth - 40.0).clamp(300.0, 370.0);
    final deckHeight =
        (deckWidth * 1.10).clamp(335.0, (screenHeight * 0.46).clamp(340.0, 415.0));

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _deckKey.currentState?.triggerSwipe(SwipeDirection.left);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _deckKey.currentState?.triggerSwipe(SwipeDirection.right);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            final current = deckState.currentTrip;
            if (current != null) _openTripDetails(current);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyZ) {
            _handleUndo();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () =>
              ref.read(deckControllerProvider.notifier).loadInitial(),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: deckState.isDeckMode ? 16 : 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 6),

                    // 1. HEADER: Avatar + Greeting, Bell, Saved Trips Bookmark with Badge
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          // User Avatar
                          CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                theme.colorScheme.primary.withAlpha(35),
                            backgroundImage: userProfile?.avatarPath != null
                                ? NetworkImage(userProfile!.avatarPath!)
                                : null,
                            child: userProfile?.avatarPath == null
                                ? Text(
                                    displayName.substring(0, 1).toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      fontSize: 15,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),

                          // Greeting & Title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_getGreeting()}, $displayName',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(160),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Discover Trips',
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                    fontSize: 16.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Host Trip Action Button (Compact modern pill)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            onPressed: () => context.push('/trip/new'),
                            icon: const Icon(
                              Icons.add_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Host',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Bookmark Icon with Saved Trips Count Badge
                          Semantics(
                            label: 'Saved Trips, $savedCount saved',
                            button: true,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 38,
                              ),
                              icon: Badge(
                                isLabelVisible: savedCount > 0,
                                label: Text('$savedCount'),
                                backgroundColor: const Color(0xFFC6E062),
                                textColor: const Color(0xFF132219),
                                child: const Icon(
                                  Icons.bookmark_outline_rounded,
                                  size: 22,
                                ),
                              ),
                              tooltip: 'Saved Trips ($savedCount)',
                              onPressed: () => context.push('/saved-trips'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 2. UPCOMING TRIPS STRIP (4 thumbnails in safe zone)
                    if (deckState.trips.isNotEmpty) ...[
                      UpcomingTripsStrip(
                        trips: deckState.trips,
                        onTapTrip: (trip) => ref
                            .read(deckControllerProvider.notifier)
                            .jumpToTrip(trip.id),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // 3. SEARCH FIELD + FILTER BUTTON (Compact modern scale)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (query) => ref
                                    .read(deckControllerProvider.notifier)
                                    .setSearchQuery(query),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13.5,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Where would you like to travel?',
                                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                    fontSize: 13.5,
                                    color: theme.colorScheme.onSurface.withAlpha(140),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  prefixIconConstraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 16,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                          onPressed: () {
                                            _searchController.clear();
                                            ref
                                                .read(deckControllerProvider
                                                    .notifier)
                                                .setSearchQuery('');
                                          },
                                        )
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withAlpha(45),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.outline.withAlpha(45),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filter Modal Button (Compact 40x40 circle)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton.filledTonal(
                              icon: const Icon(
                                Icons.tune_rounded,
                                size: 18,
                              ),
                              tooltip: 'Filter options',
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: _showFilterModal,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4. SECTION ROW: "Popular trips" with "See all" / Grid Toggle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Popular Trips',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => ref
                                .read(deckControllerProvider.notifier)
                                .toggleViewMode(),
                            icon: Icon(
                              deckState.isDeckMode
                                  ? Icons.grid_view_rounded
                                  : Icons.view_carousel_rounded,
                              size: 18,
                            ),
                            label: Text(
                              deckState.isDeckMode ? 'See all' : 'Deck',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // 5. MAIN CONTENT: Stacked Card Deck or Grid View
                    if (deckState.isLoading)
                      _buildLoadingSkeleton(context, deckWidth, deckHeight)
                    else if (deckState.errorMessage != null)
                      _buildErrorState(context, deckState.errorMessage!)
                    else if (deckState.remainingTrips.isEmpty)
                      _buildCaughtUpState(context)
                    else if (deckState.isDeckMode)
                      _buildDeckView(
                        context: context,
                        deckState: deckState,
                        deckWidth: deckWidth,
                        deckHeight: deckHeight,
                      )
                    else
                      _buildGridView(
                        context: context,
                        trips: deckState.remainingTrips,
                        savedIds: deckState.savedTripIds,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Deck View Mode ---
  Widget _buildDeckView({
    required BuildContext context,
    required DeckState deckState,
    required double deckWidth,
    required double deckHeight,
  }) {
    return SwipeableDeck(
      key: _deckKey,
      trips: deckState.remainingTrips,
      deckWidth: deckWidth,
      deckHeight: deckHeight,
      onSwipe: _handleSwipe,
      onTapTrip: _openTripDetails,
    );
  }

  // --- Grid View Mode (Tablet / Desktop / "See all") ---
  Widget _buildGridView({
    required BuildContext context,
    required List<Trip> trips,
    required Set<String> savedIds,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: trips.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 120,
            ),
            itemBuilder: (context, index) {
              final trip = trips[index];
              final isSaved = savedIds.contains(trip.id);

              return AppCard(
                variant: AppCardVariant.elevated,
                padding: const EdgeInsets.all(12),
                onTap: () => _openTripDetails(trip),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.border12,
                      child: SizedBox(
                        width: 88,
                        height: 88,
                        child: DestinationImage(
                          tripId: trip.id,
                          destination: trip.destination,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            trip.destination,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${trip.startDate.day}/${trip.startDate.month} – ${trip.endDate.day}/${trip.endDate.month}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${trip.confirmedMembersCount}/${trip.maxMembers} members',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: isSaved
                            ? const Color(0xFFC6E062)
                            : Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: isSaved ? 'Saved' : 'Save trip',
                      onPressed: () async {
                        if (isSaved) {
                          await ref
                              .read(deckControllerProvider.notifier)
                              .undo();
                        } else {
                          await ref
                              .read(deckControllerProvider.notifier)
                              .swipe(kSaveDirection);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- States: Loading Skeleton ---
  Widget _buildLoadingSkeleton(
    BuildContext context,
    double deckWidth,
    double deckHeight,
  ) {
    return Center(
      child: Column(
        children: [
          Container(
            width: deckWidth,
            height: deckHeight,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(AppRadius.r28),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: deckWidth * 0.7,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }

  // --- States: "You're all caught up" Empty State ---
  Widget _buildCaughtUpState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.done_all_rounded,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "You're all caught up!",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "You've reviewed all upcoming adventures matching your preferences. Reset skipped journeys to review them again or host your own.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(160),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(deckControllerProvider.notifier)
                    .resetSkippedTrips(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reset skipped trips'),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/trip/new'),
                icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                label: const Text('Host a trip'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- States: Error State ---
  Widget _buildErrorState(BuildContext context, String error) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ErrorView(
        title: 'Unable to load trip deck',
        message: error,
        onRetry: () =>
            ref.read(deckControllerProvider.notifier).loadInitial(),
      ),
    );
  }
}
