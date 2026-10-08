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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: call.isBothConfirmed
                            ? Colors.green.withAlpha(25)
                            : theme.colorScheme.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        call.isBothConfirmed
                            ? Icons.lock_open_rounded
                            : Icons.video_camera_front_rounded,
                        size: 17,
                        color: call.isBothConfirmed
                            ? Colors.green
                            : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        call.isBothConfirmed
                            ? 'Chat Unlocked'
                            : (call.isScheduled
                                ? 'Intro Call Scheduled'
                                : 'Intro Call Needed'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: call.isBothConfirmed
                              ? (theme.brightness == Brightness.dark
                                  ? Colors.green.shade300
                                  : Colors.green.shade800)
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
                  icon: const Icon(Icons.edit_calendar_outlined, size: 14),
                  label: const Text(
                    'Reschedule',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (call.isScheduled) ...[
            // Scheduled time
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${call.scheduledAt!.day}/${call.scheduledAt!.month}/${call.scheduledAt!.year} at ${_formatTime(call.scheduledAt!)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Meeting Link Button & Copy
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openMeetingLink(call.meetingLink!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(100),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$serviceType: ${call.meetingLink}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
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
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Copy link',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: call.meetingLink!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Meeting link copied!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dual confirmation trackers
            Wrap(
              spacing: 6,
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Schedule Intro Call',
              icon: Icons.calendar_month_rounded,
              size: AppButtonSize.small,
              onPressed: () => IntroCallDialog.show(
                context,
                introCall: call,
                tripId: widget.joinRequest.tripId,
              ),
              variant: AppButtonVariant.primary,
            ),
          ],

          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMsg!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontSize: 11,
              ),
            ),
          ],

          // Action button
          if (call.isScheduled && !call.isBothConfirmed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: hasUserConfirmed
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 15,
                      ),
                      label: Text(
                        'You confirmed · Awaiting $otherRoleLabel',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    )
                  : AppButton(
                      label: 'Confirm Intro Call Done',
                      icon: Icons.check_circle_outline_rounded,
                      size: AppButtonSize.small,
                      isFullWidth: true,
                      isLoading: _isConfirming,
                      onPressed: _handleConfirm,
                      variant: AppButtonVariant.primary,
                    ),
            ),
          ],

          if (call.isBothConfirmed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Open Trip Group Chat',
                icon: Icons.chat_rounded,
                size: AppButtonSize.small,
                isFullWidth: true,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isConfirmed
            ? Colors.green.withAlpha(20)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConfirmed ? Colors.green.withAlpha(100) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed ? Icons.check_circle : Icons.hourglass_empty_rounded,
            size: 12,
            color: isConfirmed
                ? Colors.green
                : theme.colorScheme.onSurface.withAlpha(140),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ${isConfirmed ? 'Confirmed' : 'Pending'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isConfirmed
                  ? (theme.brightness == Brightness.dark
                      ? Colors.green.shade300
                      : Colors.green.shade800)
                  : theme.colorScheme.onSurface.withAlpha(160),
              fontWeight: FontWeight.w600,
              fontSize: 10,
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
