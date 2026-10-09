import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/destination_image.dart';
import '../../../account/data/profile_repository.dart';
import '../../data/join_request_repository.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip.dart';
import 'join_request_progress_stepper.dart';

/// Modal bottom sheet presenting a streamlined, modern Join Request Submission Form.
class JoinRequestFormSheet extends ConsumerStatefulWidget {
  const JoinRequestFormSheet({
    required this.trip,
    super.key,
  });

  final Trip trip;

  /// Convenience launcher for opening the bottom sheet modal.
  static Future<bool?> show(BuildContext context, Trip trip) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JoinRequestFormSheet(trip: trip),
    );
  }

  @override
  ConsumerState<JoinRequestFormSheet> createState() => _JoinRequestFormSheetState();
}

class _JoinRequestFormSheetState extends ConsumerState<JoinRequestFormSheet> {
  final _messageController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  final List<String> _quickPrompts = const [
    '👋 Excited to join this crew!',
    '🎒 Experienced hiker & ready.',
    '📸 Big photography & roadtrip fan.',
    '☕ Flexible, chill, and easy-going.',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final note = _messageController.text.trim();
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(joinRequestRepositoryProvider)
          .sendJoinRequest(widget.trip.id, message: note);

      try {
        await ref
            .read(tripRepositoryProvider)
            .requestToJoin(widget.trip.id, message: note);
      } catch (_) {}

      ref.invalidate(myJoinRequestsProvider);
      ref.invalidate(userTripRequestProvider(widget.trip.id));

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _hasSubmitted = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Join request sent to ${widget.trip.hostDisplayName}! Next step is reviewing and intro call.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppErrorHandler.showSafeSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trip = widget.trip;
    final userProfileAsync = ref.watch(userProfileProvider);
    final userProfile = userProfileAsync.value;
    final existingRequestAsync = ref.watch(userTripRequestProvider(trip.id));
    final existingRequest = existingRequestAsync.value;

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final startMonth = months[trip.startDate.month - 1];
    final endMonth = months[trip.endDate.month - 1];
    final dateRange = trip.startDate.month == trip.endDate.month
        ? '$startMonth ${trip.startDate.day} - ${trip.endDate.day}'
        : '$startMonth ${trip.startDate.day} - $endMonth ${trip.endDate.day}';

    final isGatedAndUnverified =
        trip.requiresVerifiedMembers && (userProfile?.isVerified != true);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Trip Header Card Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer.withAlpha(120),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: DestinationImage(
                            tripId: trip.id,
                            destination: trip.destination,
                            aspectRatio: null,
                            fit: BoxFit.cover,
                            useHero: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.destination,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$dateRange • ${trip.budget != null ? '₹${trip.budget!.toStringAsFixed(0)}' : 'Shared expenses'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(160),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(
                                  Icons.person_pin_circle_outlined,
                                  size: 13,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Hosted by ${trip.hostDisplayName}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: 'View Trip Details',
                        icon: const Icon(Icons.arrow_outward_rounded, size: 20),
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/trip/${trip.id}');
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Form or Status Section
                if (_hasSubmitted || existingRequest != null) ...[
                  // State: Already Submitted
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Join Request Submitted',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your request has been delivered to ${trip.hostDisplayName}. Once reviewed, you can schedule your 10-minute intro call.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        if (existingRequest != null) ...[
                          const SizedBox(height: 16),
                          JoinRequestProgressStepper(stage: existingRequest.stage),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Close Form',
                    isPill: true,
                    isFullWidth: true,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ] else if (isGatedAndUnverified) ...[
                  // State: Verification Required
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.withAlpha(120),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Colors.amber,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Identity Verification Required',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800] ?? Colors.amber,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The host has marked this departure for identity-verified travellers only. Take a 60-second selfie check to unlock joining.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppButton(
                          label: 'Complete Verification',
                          icon: Icons.shield_outlined,
                          isPill: true,
                          size: AppButtonSize.small,
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.push('/verification');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // State: Normal Form
                  Text(
                    'Request to Join',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send a personal message to introduce yourself and tell the host why you\'d make a great travel companion.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(150),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Quick prompts chips
                  Text(
                    'Quick Prompts:',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final prompt in _quickPrompts)
                        ActionChip(
                          label: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withAlpha(190),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.borderPill,
                          ),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                          onPressed: () {
                            final current = _messageController.text.trim();
                            if (current.isEmpty) {
                              _messageController.text = prompt;
                            } else {
                              _messageController.text = '$current $prompt';
                            }
                            _messageController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _messageController.text.length),
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Note input
                  TextField(
                    controller: _messageController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Share why you\'re excited, travel experience, or any questions...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurface.withAlpha(110),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withAlpha(80),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant.withAlpha(80),
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

                  const SizedBox(height: 12),

                  // Intro call notice
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.video_camera_front_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Next step: Once the host accepts your request, you\'ll schedule a 10-minute intro video call to ensure great travel synergy.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(140),
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Submit CTA
                  AppButton(
                    label: trip.availablePlaces > 0
                        ? 'Submit Join Request'
                        : 'Trip is Full',
                    icon: Icons.send_rounded,
                    isLoading: _isSubmitting,
                    isPill: true,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                    onPressed: trip.availablePlaces > 0 ? _handleSubmit : null,
                  ),
                ],

                const SizedBox(height: 8),

                // Link to full details
                Center(
                  child: TextButton.icon(
                    icon: const Text('View Full Trip Details'),
                    label: const Icon(Icons.arrow_forward_rounded, size: 14),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/trip/${trip.id}');
                    },
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
