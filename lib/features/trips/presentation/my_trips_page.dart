import 'package:flutter/material.dart';
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pagePadding(context),
                12,
                AppSpacing.pagePadding(context),
                8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Trips',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Manage your hosted departures and submitted join requests.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(140),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedTabs(
                    tabs: const ['Departures', 'Requests'],
                    selectedIndex: _tabController.index,
                    height: 38.0,
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
                        const SizedBox(height: 88),
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
                        return const SizedBox(height: 88);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
                        return const SizedBox(height: 88);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
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
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final cardBg = theme.colorScheme.surface;

    final dateStr =
        '${widget.trip.startDate.day}/${widget.trip.startDate.month} – ${widget.trip.endDate.day}/${widget.trip.endDate.month}';

    return AnimatedScale(
      scale: _isPressed && !disableAnimations ? 0.98 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(70),
            width: 1,
          ),
          boxShadow: AppShadows.subtle(context),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.push(
              '/trip/${widget.trip.id}',
              extra: widget.trip,
            ),
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  // Photo Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: DestinationImage(
                        tripId: 'mytrip-${widget.trip.id}',
                        destination: widget.trip.destination,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        aspectRatio: 1.0,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

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
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      dateStr,
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 10.5,
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
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                widget.trip.status.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Title
                        Text(
                          widget.trip.destination,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),

                        // Members and places
                        Row(
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 12,
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.trip.confirmedMembersCount}/${widget.trip.maxMembers} confirmed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurface.withAlpha(150),
                                fontSize: 10.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.primary.withAlpha(20),
                              ),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(70),
          width: 1,
        ),
        boxShadow: AppShadows.subtle(context),
      ),
      padding: const EdgeInsets.all(12),
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
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    fontSize: 14.5,
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
                    horizontal: 8,
                    vertical: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Trip',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          JoinRequestProgressStepper(stage: request.stage),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Your note: "${request.message!}"',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ),
          ],
          if (request.isAccepted && request.introCall != null) ...[
            const SizedBox(height: 10),
            IntroCallCard(joinRequest: request, isHost: false),
          ],
        ],
      ),
    );
  }
}
