import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/join_request_repository.dart';
import '../data/trip_repository.dart';
import '../domain/join_request.dart';
import '../domain/trip.dart';
import 'widgets/intro_call_card.dart';
import 'widgets/join_request_progress_stepper.dart';

class MyTripsPage extends ConsumerStatefulWidget {
  const MyTripsPage({super.key});

  @override
  ConsumerState<MyTripsPage> createState() => _MyTripsPageState();
}

class _MyTripsPageState extends ConsumerState<MyTripsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(myTripsProvider);
    final myRequestsAsync = ref.watch(myJoinRequestsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.selectionClick();
            context.push('/trip/new');
          },
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'New Trip',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.2),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.borderPill,
          ),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePadding(context),
                16,
                AppSpacing.pagePadding(context),
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Trips',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your hosted departures and submitted join requests.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  SegmentedTabs(
                    tabs: const ['Departures', 'Requests'],
                    selectedIndex: _tabController.index,
                    onChanged: (index) {
                      _tabController.animateTo(index);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Departures
            RefreshIndicator(
              onRefresh: () => ref.refresh(myTripsProvider.future),
              child: tripsAsync.when(
                data: (trips) {
                  if (trips.isEmpty) {
                    return ListView(
                      padding: AppSpacing.pagePaddingInsets(context),
                      children: [
                        const SizedBox(height: 40),
                        EmptyState(
                          title: 'No upcoming departures yet',
                          message:
                              'You haven\'t planned any adventures or joined one yet. Explore open departures or host your own!',
                          icon: Icons.luggage_outlined,
                          actionLabel: 'Explore Open Trips',
                          onActionPressed: () => context.go('/discover'),
                        ),
                        const SizedBox(height: AppSpacing.s80),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: AppSpacing.pagePaddingInsets(
                      context,
                      vertical: AppSpacing.s8,
                    ),
                    itemCount: trips.length + 1,
                    itemBuilder: (context, index) {
                      if (index == trips.length) {
                        return const SizedBox(height: AppSpacing.s80);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: _MyTripCard(trip: trips[index])
                            .animateEntrance(context: context, index: index),
                      );
                    },
                  );
                },
                loading: () => const LoadingView(
                  message: 'Loading your trips...',
                  isFullPage: false,
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.refresh(myTripsProvider),
                  isFullPage: false,
                ),
              ),
            ),

            // Tab 2: Join Requests & Intro Calls
            RefreshIndicator(
              onRefresh: () => ref.refresh(myJoinRequestsProvider.future),
              child: myRequestsAsync.when(
                data: (requests) {
                  if (requests.isEmpty) {
                    return ListView(
                      padding: AppSpacing.pagePaddingInsets(context),
                      children: [
                        const SizedBox(height: 40),
                        EmptyState(
                          title: 'No join requests sent',
                          message:
                              'When you request to join fellow solo travellers\' trips, you can track progress and coordinate intro calls here.',
                          icon: Icons.send_outlined,
                          actionLabel: 'Discover Trips',
                          onActionPressed: () => context.go('/discover'),
                        ),
                        const SizedBox(height: AppSpacing.s80),
                      ],
                    );
                  }
                  return ListView.builder(
                    padding: AppSpacing.pagePaddingInsets(
                      context,
                      vertical: AppSpacing.s8,
                    ),
                    itemCount: requests.length + 1,
                    itemBuilder: (context, index) {
                      if (index == requests.length) {
                        return const SizedBox(height: AppSpacing.s80);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: _MySubmittedRequestCard(request: requests[index])
                            .animateEntrance(context: context, index: index),
                      );
                    },
                  );
                },
                loading: () => const LoadingView(
                  message: 'Loading your requests...',
                  isFullPage: false,
                ),
                error: (error, _) => ErrorView(
                  error: error,
                  onRetry: () => ref.refresh(myJoinRequestsProvider),
                  isFullPage: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyTripCard extends StatefulWidget {
  const _MyTripCard({required this.trip});

  final Trip trip;

  @override
  State<_MyTripCard> createState() => _MyTripCardState();
}

class _MyTripCardState extends State<_MyTripCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final cardBg = isDark
        ? AppTheme.darkForestSurfaceDark
        : theme.colorScheme.surface;

    final dateStr =
        '${widget.trip.startDate.day}/${widget.trip.startDate.month} – ${widget.trip.endDate.day}/${widget.trip.endDate.month}';

    return AnimatedScale(
      scale: _isPressed && !disableAnimations ? 0.98 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: AppRadius.border20,
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(20)
                : theme.colorScheme.outlineVariant.withAlpha(80),
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
                      width: 80,
                      height: 80,
                      child: DestinationImage(
                        tripId: 'mytrip-${widget.trip.id}',
                        destination: widget.trip.destination,
                        width: 80,
                        height: 80,
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
                        // Dates & Status Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 11,
                                    color: isDark
                                        ? AppTheme.lime
                                        : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      dateStr,
                                      style: TextStyle(
                                        color: isDark
                                            ? AppTheme.lime
                                            : theme.colorScheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(20),
                                borderRadius: AppRadius.borderPill,
                              ),
                              child: Text(
                                widget.trip.status.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Title
                        Text(
                          widget.trip.destination,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Members and places
                        Row(
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 13,
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.trip.confirmedMembersCount}/${widget.trip.maxMembers} confirmed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(150),
                                fontSize: 11,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withAlpha(25),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
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

class _MySubmittedRequestCard extends ConsumerWidget {
  const _MySubmittedRequestCard({required this.request});

  final JoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkForestSurfaceDark
            : theme.colorScheme.surface,
        borderRadius: AppRadius.border20,
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : theme.colorScheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
        boxShadow: AppShadows.subtle(context),
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  request.tripDestination ?? 'Adventure Trip',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => context.push('/trip/${request.tripId}'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View Trip'),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          JoinRequestProgressStepper(stage: request.stage),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: AppRadius.border12,
              ),
              child: Text(
                'Your note: "${request.message!}"',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              ),
            ),
          ],
          if (request.isAccepted && request.introCall != null) ...[
            const SizedBox(height: 14),
            IntroCallCard(joinRequest: request, isHost: false),
          ],
        ],
      ),
    );
  }
}
