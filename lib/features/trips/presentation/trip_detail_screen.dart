import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../account/data/auth_repository.dart';
import '../../account/data/profile_repository.dart';
import '../data/join_request_repository.dart';
import '../data/trip_repository.dart';
import '../domain/join_request.dart';
import '../domain/travel_compatibility.dart';
import '../domain/trip.dart';
import 'widgets/intro_call_card.dart';
import 'widgets/join_request_form_sheet.dart';
import 'widgets/join_request_progress_stepper.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  Trip? _trip;
  bool _isLoading = true;
  bool _hasRequested = false;
  bool _isMember = false;
  bool _isFavorite = false;
  String? _signedHostAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    setState(() => _isLoading = true);
    final repo = ref.read(tripRepositoryProvider);

    try {
      final trip = await repo.getTripById(widget.tripId);
      final hasRequested = await repo.hasRequestedToJoin(widget.tripId);
      final isMember = await repo.isTripMember(widget.tripId);

      if (mounted) {
        setState(() {
          _trip = trip;
          _hasRequested = hasRequested;
          _isMember = isMember;
          _isLoading = false;
        });

        if (trip?.hostAvatarPath != null && trip!.hostAvatarPath!.isNotEmpty) {
          final url = await ref
              .read(profileRepositoryProvider)
              .getAvatarSignedUrl(trip.hostAvatarPath!);
          if (mounted && url != null) {
            setState(() => _signedHostAvatarUrl = url);
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRequestToJoin() async {
    if (_trip == null) return;
    await JoinRequestFormSheet.show(context, _trip!);
    if (mounted) {
      await _loadTrip();
    }
  }

  Future<void> _handleCancelRequest(String requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Join Request?'),
        content: const Text(
          'Are you sure you want to withdraw your request to join this trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Request'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Withdraw Request'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref
          .read(joinRequestRepositoryProvider)
          .cancelJoinRequest(requestId);
      ref.invalidate(userTripRequestProvider(widget.tripId));
      ref.invalidate(tripJoinRequestsProvider(widget.tripId));
      ref.invalidate(myJoinRequestsProvider);
      setState(() => _hasRequested = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join request cancelled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSafeSnackBar(context, e);
      }
    }
  }

  Future<void> _handleCancelTrip() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
          'Are you sure you want to cancel this trip? Members will be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Trip'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(tripRepositoryProvider).cancelTrip(widget.tripId);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Trip cancelled.')));
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSafeSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final userProfile = ref.watch(userProfileProvider).value;

    if (_isLoading) {
      return const _TripDetailLoadingSkeleton();
    }

    final trip = _trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          title: 'Trip not found',
          message: 'This adventure may have been cancelled or removed.',
          onRetry: _loadTrip,
        ),
      );
    }

    final isHost = currentUser != null && currentUser.id == trip.hostId;
    final requestsAsync = isHost
        ? ref.watch(tripJoinRequestsProvider(trip.id))
        : null;
    final pendingRequestsCount =
        requestsAsync?.value?.where((r) => r.isPending).length ?? 0;
    final userRequestAsync = !isHost
        ? ref.watch(userTripRequestProvider(trip.id))
        : null;
    final userRequest = userRequestAsync?.value;

    final compatibilityLabels = TravelCompatibility.computeLabels(
      userStyle: userProfile?.travelStyle ?? const {},
      hostStyle: trip.hostTravelStyle,
    );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Center(
          child: GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
        ),
        actions: [
          GlassIconButton(
            icon: _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: _isFavorite
                ? Colors.redAccent
                : const Color(0xFF132219),
            tooltip:
                _isFavorite ? 'Remove from favorites' : 'Save to favorites',
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _isFavorite
                        ? 'Saved to favorite trips'
                        : 'Removed from favorites',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.s4),
          GlassIconButton(
            icon: Icons.share_rounded,
            tooltip: 'Share Trip',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Trip link copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          if (isHost) ...[
            const SizedBox(width: AppSpacing.s4),
            GlassIconButton(
              icon: Icons.people_alt_outlined,
              tooltip: 'Review Requests',
              badge: pendingRequestsCount > 0
                  ? Badge(
                      label: Text('$pendingRequestsCount'),
                      child: const Icon(
                        Icons.people_alt_outlined,
                        size: 20,
                        color: Color(0xFF132219),
                      ),
                    )
                  : null,
              onPressed: () => context.push('/trip/${trip.id}/requests'),
            ),
            const SizedBox(width: AppSpacing.s4),
            GlassIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit Trip',
              onPressed: () =>
                  context.push('/trip/edit/${trip.id}', extra: trip),
            ),
          ],
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: GlassContainer(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.r20),
          ),
          blur: 20.0,
          tintColor: const Color(0xEEFFFFFF),
          borderColor: const Color(0x40D8E2D8),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _buildStickyBottomAction(
                context: context,
                trip: trip,
                isHost: isHost,
                pendingRequestsCount: pendingRequestsCount,
                userRequest: userRequest,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                DestinationImage(
                  tripId: trip.id,
                  destination: trip.destination,
                  height: 300,
                  aspectRatio: null,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.zero,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withAlpha(20),
                          Colors.black.withAlpha(160),
                        ],
                        stops: const [0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.s16,
                  bottom: 36,
                  right: AppSpacing.s16,
                  child: Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    children: [
                      InfoChip(
                        variant: InfoChipVariant.glass,
                        icon: Icons.calendar_today_rounded,
                        label:
                            '${trip.startDate.day}/${trip.startDate.month} – ${trip.endDate.day}/${trip.endDate.month}',
                      ),
                      InfoChip(
                        variant: InfoChipVariant.glass,
                        icon: Icons.group_rounded,
                        label:
                            '${trip.confirmedMembersCount}/${trip.maxMembers} members',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.r32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s24,
                  AppSpacing.s16,
                  AppSpacing.s32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Uppercase destination label pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(25),
                            borderRadius: AppRadius.borderPill,
                            border: Border.all(
                              color: theme.colorScheme.primary.withAlpha(50),
                            ),
                          ),
                          child: Text(
                            trip.destination.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        // Display Title
                        Text(
                          trip.destination,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Info Chips
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: [
                            _buildInfoChip(
                              theme,
                              icon: Icons.schedule_rounded,
                              label: '${trip.durationDays} Days',
                            ),
                            _buildInfoChip(
                              theme,
                              icon: Icons.calendar_today_rounded,
                              label:
                                  '${trip.startDate.day}/${trip.startDate.month} – ${trip.endDate.day}/${trip.endDate.month}',
                            ),
                            if (trip.budget != null)
                              _buildInfoChip(
                                theme,
                                icon: Icons.payments_outlined,
                                label: '\$${trip.budget!.round()} est.',
                              ),
                            _buildInfoChip(
                              theme,
                              icon: Icons.group_rounded,
                              label:
                                  '${trip.confirmedMembersCount}/${trip.maxMembers} members',
                            ),
                            if (trip.requiresVerifiedMembers)
                              _buildInfoChip(
                                theme,
                                icon: Icons.verified_user_rounded,
                                label: 'Verified Only',
                                isAccent: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Member Avatar Stack Card
                        AppCard(
                          variant: AppCardVariant.outlined,
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          child: Row(
                            children: [
                              AvatarStack(
                                totalMembers: trip.maxMembers,
                                isVerifiedViewer:
                                    userProfile?.isVerified == true,
                                avatarUrls: _signedHostAvatarUrl != null
                                    ? [_signedHostAvatarUrl]
                                    : const [],
                                avatarSize: 32,
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Trip Members',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${trip.confirmedMembersCount} confirmed · ${trip.availablePlaces} spots remaining',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(150),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Host Profile Card with Verified Badge
                        AppCard(
                          variant: AppCardVariant.outlined,
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hosted by',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withAlpha(140),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: theme.colorScheme.primary
                                        .withAlpha(25),
                                    backgroundImage: _signedHostAvatarUrl !=
                                            null
                                        ? NetworkImage(_signedHostAvatarUrl!)
                                        : null,
                                    child: _signedHostAvatarUrl == null
                                        ? Icon(
                                            Icons.person_rounded,
                                            size: 32,
                                            color: theme.colorScheme.primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                trip.hostDisplayName,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (trip.hostIsVerified)
                                              Tooltip(
                                                message:
                                                    'Verified Solo Traveller',
                                                child: Icon(
                                                  Icons.verified_rounded,
                                                  size: 18,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isHost
                                              ? 'You are the host'
                                              : 'Trip Organizer',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withAlpha(150),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (compatibilityLabels.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.s16),
                                Divider(
                                  color:
                                      theme.colorScheme.outline.withAlpha(60),
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                Text(
                                  'Travel Vibe Compatibility',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final label in compatibilityLabels)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondary
                                              .withAlpha(20),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.fromBorderSide(
                                            BorderSide(
                                              color: theme.colorScheme.secondary
                                                  .withAlpha(60),
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: theme.colorScheme.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Meeting-point Card
                        AppCard(
                          variant: AppCardVariant.outlined,
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.primary.withAlpha(25),
                                  borderRadius: AppRadius.border12,
                                ),
                                child: Icon(
                                  Icons.place_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Meeting Point & Departure',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${trip.destination} Central Hub',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Arrival rendezvous point will be confirmed in group chat once your intro call is confirmed with the host.',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(150),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Overview & Description
                        AppCard(
                          variant: AppCardVariant.outlined,
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About this Adventure',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              Text(
                                trip.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                              if (trip.tags.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.s16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final tag in trip.tags)
                                      Chip(
                                        label: Text(tag),
                                        padding: EdgeInsets.zero,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: AppRadius.borderPill,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s24),

                        // Member / Request Status Banner in sheet if active
                        if (_isMember) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'You are a confirmed member of this trip!',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (userRequest != null &&
                              userRequest.introCall != null) ...[
                            const SizedBox(height: 14),
                            IntroCallCard(
                              joinRequest: userRequest,
                              isHost: false,
                            ),
                          ],
                        ] else if (userRequest != null || _hasRequested) ...[
                          if (userRequest != null) ...[
                            JoinRequestProgressStepper(
                              stage: userRequest.stage,
                            ),
                            const SizedBox(height: 14),
                            if (userRequest.isAccepted &&
                              userRequest.introCall != null) ...[
                              IntroCallCard(
                                joinRequest: userRequest,
                                isHost: false,
                              ),
                              const SizedBox(height: 14),
                            ],
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.secondary.withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.hourglass_top_rounded,
                                    color: theme.colorScheme.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Join Request Submitted',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAccent
            ? theme.colorScheme.primary.withAlpha(25)
            : theme.colorScheme.surfaceContainerHighest.withAlpha(140),
        borderRadius: AppRadius.borderPill,
        border: Border.all(
          color: isAccent
              ? theme.colorScheme.primary.withAlpha(60)
              : theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isAccent
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withAlpha(180),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isAccent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomAction({
    required BuildContext context,
    required Trip trip,
    required bool isHost,
    required int pendingRequestsCount,
    required JoinRequest? userRequest,
  }) {
    final theme = Theme.of(context);

    if (isHost) {
      return Row(
        children: [
          Expanded(
            child: AppButton(
              label: pendingRequestsCount > 0
                  ? 'Review Requests ($pendingRequestsCount)'
                  : 'Manage Requests',
              icon: Icons.people_alt_rounded,
              isPill: true,
              onPressed: () => context.push('/trip/${trip.id}/requests'),
              size: AppButtonSize.large,
              variant: AppButtonVariant.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          IconButton.outlined(
            icon: const Icon(Icons.cancel_outlined),
            tooltip: 'Cancel Trip',
            onPressed: _handleCancelTrip,
          ),
        ],
      );
    }

    if (_isMember) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              'You are a confirmed member',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (userRequest != null && userRequest.isPending) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleCancelRequest(userRequest.id),
              icon: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
              label: Text(
                'Cancel Join Request',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderPill,
                ),
                side: BorderSide(color: theme.colorScheme.error.withAlpha(100)),
              ),
            ),
          ),
        ],
      );
    }

    if (userRequest != null || _hasRequested) {
      return Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondary.withAlpha(20),
          borderRadius: AppRadius.borderPill,
          border: Border.all(
            color: theme.colorScheme.secondary.withAlpha(60),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Join Request Submitted',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      );
    }

    return AppButton(
      label: trip.availablePlaces > 0
          ? 'Request to Join Adventure'
          : 'Trip is Full',
      icon: Icons.group_add_rounded,
      isPill: true,
      isFullWidth: true,
      onPressed: trip.availablePlaces > 0 ? _handleRequestToJoin : null,
      size: AppButtonSize.large,
    );
  }
}

class _TripDetailLoadingSkeleton extends StatelessWidget {
  const _TripDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainer;

    return Scaffold(
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            Container(
              height: 290,
              width: double.infinity,
              color: placeholderColor,
            ),
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.r32),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 24,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: AppRadius.borderPill,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Container(
                          width: 260,
                          height: 32,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        Container(
                          width: double.infinity,
                          height: 100,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(AppRadius.r20),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        Container(
                          width: double.infinity,
                          height: 140,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(AppRadius.r20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
