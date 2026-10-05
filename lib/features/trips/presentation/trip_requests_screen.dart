import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../account/data/profile_repository.dart';
import '../data/join_request_repository.dart';
import '../data/trip_repository.dart';
import '../domain/join_request.dart';
import '../domain/travel_compatibility.dart';
import '../domain/trip.dart';
import 'widgets/intro_call_card.dart';
import 'widgets/join_request_progress_stepper.dart';

class TripRequestsScreen extends ConsumerStatefulWidget {
  const TripRequestsScreen({required this.tripId, super.key});

  final String tripId;

  @override
  ConsumerState<TripRequestsScreen> createState() => _TripRequestsScreenState();
}

class _TripRequestsScreenState extends ConsumerState<TripRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(tripJoinRequestsProvider(widget.tripId));
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    final currentUserProfile = ref.watch(userProfileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Join Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted & Calls'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: tripAsync.when(
        data: (trip) {
          if (trip == null) {
            return const ErrorView(title: 'Trip not found');
          }

          return requestsAsync.when(
            data: (requests) {
              final pending = requests.where((r) => r.isPending).toList();
              final accepted = requests.where((r) => r.isAccepted).toList();
              final history = requests
                  .where(
                    (r) => r.isDeclined || r.isCancelled || r.isChatUnlocked,
                  )
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _RequestListView(
                    requests: pending,
                    trip: trip,
                    hostTravelStyle:
                        currentUserProfile?.travelStyle ?? trip.hostTravelStyle,
                    emptyTitle: 'No pending requests',
                    emptyMessage: 'When solo travellers ask to join your departure, their applications will show up here.',
                  ),
                  _RequestListView(
                    requests: accepted,
                    trip: trip,
                    hostTravelStyle:
                        currentUserProfile?.travelStyle ?? trip.hostTravelStyle,
                    emptyTitle: 'No accepted requests yet',
                    emptyMessage: 'Accepted travellers you need to schedule an intro call with appear here.',
                  ),
                  _RequestListView(
                    requests: history,
                    trip: trip,
                    hostTravelStyle:
                        currentUserProfile?.travelStyle ?? trip.hostTravelStyle,
                    emptyTitle: 'No past request history',
                    emptyMessage:
                        'Completed or declined applications will appear here.',
                  ),
                ],
              );
            },
            loading: () => const LoadingView(message: 'Loading requests...'),
            error: (err, _) => ErrorView(
              error: err,
              onRetry: () =>
                  ref.refresh(tripJoinRequestsProvider(widget.tripId)),
            ),
          );
        },
        loading: () => const LoadingView(message: 'Loading trip details...'),
        error: (err, _) => ErrorView(error: err),
      ),
    );
  }
}

class _RequestListView extends StatelessWidget {
  const _RequestListView({
    required this.requests,
    required this.trip,
    required this.hostTravelStyle,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<JoinRequest> requests;
  final Trip trip;
  final Map<String, dynamic> hostTravelStyle;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: EmptyState(
          title: emptyTitle,
          message: emptyMessage,
          icon: Icons.group_outlined,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _ApplicantRequestCard(
          request: requests[index],
          trip: trip,
          hostTravelStyle: hostTravelStyle,
        );
      },
    );
  }
}

class _ApplicantRequestCard extends ConsumerStatefulWidget {
  const _ApplicantRequestCard({
    required this.request,
    required this.trip,
    required this.hostTravelStyle,
  });

  final JoinRequest request;
  final Trip trip;
  final Map<String, dynamic> hostTravelStyle;

  @override
  ConsumerState<_ApplicantRequestCard> createState() =>
      _ApplicantRequestCardState();
}

class _ApplicantRequestCardState extends ConsumerState<_ApplicantRequestCard> {
  bool _isProcessing = false;
  String? _error;

  Future<void> _handleAccept() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await ref
          .read(joinRequestRepositoryProvider)
          .acceptJoinRequest(widget.request.id);

      ref.invalidate(tripJoinRequestsProvider(widget.trip.id));
      ref.invalidate(tripDetailProvider(widget.trip.id));
      ref.invalidate(discoverTripsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request accepted! Now schedule an intro call.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleDecline() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      await ref
          .read(joinRequestRepositoryProvider)
          .declineJoinRequest(widget.request.id);

      ref.invalidate(tripJoinRequestsProvider(widget.trip.id));

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request declined.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applicant = widget.request.applicant;
    final isFull = widget.trip.availablePlaces <= 0;

    // Plain compatibility badges - STRICTLY NO PERCENTAGES
    final compatibilityBadges = TravelCompatibility.computeLabels(
      userStyle: applicant?.travelStyle ?? const {},
      hostStyle: widget.hostTravelStyle,
    );

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Applicant Header: Avatar, Name, Verified Badge
          Row(
            children: [
              _ApplicantAvatar(applicant: applicant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            applicant?.displayName ?? 'Adventurer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (applicant?.isVerified ?? false) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.request.createdAt != null
                          ? 'Requested ${_formatDate(widget.request.createdAt!)}'
                          : 'Recent request',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStageBadgeColor(
                    theme,
                    widget.request.stage,
                  ).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.request.stage.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getStageBadgeColor(theme, widget.request.stage),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Applicant Message / Note
          if (widget.request.message != null &&
              widget.request.message!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${widget.request.message!}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Compatibility Badges (Plain text labels only)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final badge in compatibilityBadges)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(40),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // State Machine Stepper
          JoinRequestProgressStepper(stage: widget.request.stage),

          // Intro Call Card embedded if accepted
          if (widget.request.isAccepted &&
              widget.request.introCall != null) ...[
            const SizedBox(height: 16),
            IntroCallCard(joinRequest: widget.request, isHost: true),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],

          // Pending Actions for Host
          if (widget.request.isPending) ...[
            const SizedBox(height: 18),
            if (isFull)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Trip capacity limit reached (${widget.trip.maxMembers} members). Increase capacity or decline pending requests.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _handleDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(
                        color: theme.colorScheme.error.withAlpha(120),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Accept & Schedule',
                    icon: Icons.check,
                    isLoading: _isProcessing,
                    onPressed: isFull ? null : _handleAccept,
                    variant: AppButtonVariant.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStageBadgeColor(ThemeData theme, JoinRequestStage stage) {
    switch (stage) {
      case JoinRequestStage.bothConfirmed:
        return Colors.green;
      case JoinRequestStage.declined:
      case JoinRequestStage.cancelled:
        return theme.colorScheme.error;
      case JoinRequestStage.accepted:
      case JoinRequestStage.callScheduled:
      case JoinRequestStage.requested:
        return theme.colorScheme.primary;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ApplicantAvatar extends StatelessWidget {
  const _ApplicantAvatar({required this.applicant});

  final ApplicantProfile? applicant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = applicant?.displayName ?? 'Adventurer';

    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.primary.withAlpha(25),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
