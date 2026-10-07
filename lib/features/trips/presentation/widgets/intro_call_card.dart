import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/meeting_link_validator.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/join_request_repository.dart';
import '../../domain/join_request.dart';
import 'intro_call_dialog.dart';

class IntroCallCard extends ConsumerStatefulWidget {
  const IntroCallCard({
    required this.joinRequest,
    required this.isHost,
    super.key,
  });

  final JoinRequest joinRequest;
  final bool isHost;

  @override
  ConsumerState<IntroCallCard> createState() => _IntroCallCardState();
}

class _IntroCallCardState extends ConsumerState<IntroCallCard> {
  bool _isConfirming = false;
  String? _errorMsg;

  Future<void> _handleConfirm() async {
    final introCall = widget.joinRequest.introCall;
    if (introCall == null) return;

    setState(() {
      _isConfirming = true;
      _errorMsg = null;
    });

    try {
      final chatUnlocked = await ref
          .read(joinRequestRepositoryProvider)
          .confirmIntroCall(introCall.id);

      // Refresh data
      ref.invalidate(tripJoinRequestsProvider(widget.joinRequest.tripId));
      ref.invalidate(userTripRequestProvider(widget.joinRequest.tripId));
      ref.invalidate(myJoinRequestsProvider);

      if (mounted) {
        setState(() => _isConfirming = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatUnlocked
                  ? 'Both confirmed! Trip chat is now unlocked 🎉'
                  : 'Intro call confirmed! Waiting for other participant.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _openMeetingLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Meeting link copied! Paste into your browser or app to join.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final call = widget.joinRequest.introCall;

    if (call == null) {
      return const SizedBox.shrink();
    }

    final hasUserConfirmed = widget.isHost
        ? call.hostConfirmed
        : call.travellerConfirmed;
    final otherConfirmed = widget.isHost
        ? call.travellerConfirmed
        : call.hostConfirmed;
    final otherRoleLabel = widget.isHost ? 'Applicant' : 'Host';
    final serviceType = MeetingLinkValidator.getServiceType(call.meetingLink);

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: call.isBothConfirmed
                            ? Colors.green.withAlpha(30)
                            : theme.colorScheme.primary.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        call.isBothConfirmed
                            ? Icons.lock_open_rounded
                            : Icons.video_camera_front_rounded,
                        size: 20,
                        color: call.isBothConfirmed
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        call.isBothConfirmed
                            ? 'Chat Unlocked'
                            : (call.isScheduled
                                  ? 'Intro Call Scheduled'
                                  : 'Intro Call Needed'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: call.isBothConfirmed
                              ? Colors.green.shade800
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (call.isScheduled && !call.isBothConfirmed)
                TextButton.icon(
                  onPressed: () => IntroCallDialog.show(
                    context,
                    introCall: call,
                    tripId: widget.joinRequest.tripId,
                  ),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Reschedule'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (call.isScheduled) ...[
            // Scheduled time
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${call.scheduledAt!.day}/${call.scheduledAt!.month}/${call.scheduledAt!.year} at ${_formatTime(call.scheduledAt!)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Meeting Link Button & Copy
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openMeetingLink(call.meetingLink!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(120),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$serviceType: ${call.meetingLink}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy link',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: call.meetingLink!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Meeting link copied!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dual confirmation trackers
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildConfirmationBadge(
                  context,
                  label: 'You',
                  isConfirmed: hasUserConfirmed,
                ),
                _buildConfirmationBadge(
                  context,
                  label: otherRoleLabel,
                  isConfirmed: otherConfirmed,
                ),
              ],
            ),
          ] else ...[
            Text(
              'Either side can propose a time and share a meeting link to get the intro call rolling.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Schedule Intro Call',
              icon: Icons.calendar_month_rounded,
              onPressed: () => IntroCallDialog.show(
                context,
                introCall: call,
                tripId: widget.joinRequest.tripId,
              ),
              variant: AppButtonVariant.primary,
            ),
          ],

          if (_errorMsg != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMsg!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],

          // Action button
          if (call.isScheduled && !call.isBothConfirmed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: hasUserConfirmed
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                      ),
                      label: Text('You confirmed · Awaiting $otherRoleLabel'),
                    )
                  : AppButton(
                      label: 'Confirm Intro Call Done',
                      icon: Icons.check_circle_outline_rounded,
                      isLoading: _isConfirming,
                      onPressed: _handleConfirm,
                      variant: AppButtonVariant.primary,
                    ),
            ),
          ],

          if (call.isBothConfirmed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Open Trip Group Chat',
                icon: Icons.chat_rounded,
                onPressed: () => context.go('/chats'),
                variant: AppButtonVariant.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmationBadge(
    BuildContext context, {
    required String label,
    required bool isConfirmed,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConfirmed
            ? Colors.green.withAlpha(20)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfirmed ? Colors.green.withAlpha(100) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.hourglass_empty_rounded,
            size: 14,
            color: isConfirmed
                ? Colors.green
                : theme.colorScheme.onSurface.withAlpha(140),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${isConfirmed ? 'Confirmed' : 'Pending'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isConfirmed
                  ? Colors.green.shade800
                  : theme.colorScheme.onSurface.withAlpha(160),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
