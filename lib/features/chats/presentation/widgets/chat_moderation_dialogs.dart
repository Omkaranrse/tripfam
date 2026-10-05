import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/chat_repository.dart';

class ChatReportDialog extends ConsumerStatefulWidget {
  const ChatReportDialog({
    required this.reportedUserId,
    required this.reportedUserName,
    this.tripId,
    super.key,
  });

  final String reportedUserId;
  final String reportedUserName;
  final String? tripId;

  static Future<bool?> show(
    BuildContext context, {
    required String reportedUserId,
    required String reportedUserName,
    String? tripId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ChatReportDialog(
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        tripId: tripId,
      ),
    );
  }

  @override
  ConsumerState<ChatReportDialog> createState() => _ChatReportDialogState();
}

class _ChatReportDialogState extends ConsumerState<ChatReportDialog> {
  final _detailsController = TextEditingController();
  String _selectedReason = 'Inappropriate content';
  bool _isSubmitting = false;
  String? _error;

  static const _reasons = [
    'Inappropriate content',
    'Harassment or bullying',
    'Spam or scam',
    'Safety concern',
    'Off-platform solicitation',
    'Other violation',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(chatRepositoryProvider)
          .reportUser(
            widget.reportedUserId,
            reason: _selectedReason,
            details: _detailsController.text.trim(),
            tripId: widget.tripId,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flag_rounded, color: theme.colorScheme.error, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report ${widget.reportedUserName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please tell us why you are reporting this user. Our safety team reviews all reports strictly and confidentially.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _reasons.map((reason) {
                return DropdownMenuItem(value: reason, child: Text(reason));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedReason = value);
                }
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _detailsController,
              label: 'Additional Details (Optional)',
              hint: 'Describe what happened (max 2000 characters)',
              maxLines: 3,
              maxLength: 2000,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Submit Report',
          isLoading: _isSubmitting,
          variant: AppButtonVariant.primary,
          onPressed: _submitReport,
        ),
      ],
    );
  }
}

class ChatBlockConfirmDialog extends ConsumerStatefulWidget {
  const ChatBlockConfirmDialog({
    required this.userId,
    required this.userName,
    super.key,
  });

  final String userId;
  final String userName;

  static Future<bool?> show(
    BuildContext context, {
    required String userId,
    required String userName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) =>
          ChatBlockConfirmDialog(userId: userId, userName: userName),
    );
  }

  @override
  ConsumerState<ChatBlockConfirmDialog> createState() =>
      _ChatBlockConfirmDialogState();
}

class _ChatBlockConfirmDialogState
    extends ConsumerState<ChatBlockConfirmDialog> {
  bool _isSubmitting = false;
  String? _error;

  Future<void> _blockUser() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(chatRepositoryProvider).blockUser(widget.userId);
      ref.invalidate(blockedUsersProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.block_rounded, color: theme.colorScheme.error, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Block ${widget.userName}?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When you block ${widget.userName}:',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _bulletPoint(
            theme,
            'Their messages will immediately disappear from your chat view.',
          ),
          _bulletPoint(
            theme,
            'They will no longer be able to message you or see your trips.',
          ),
          _bulletPoint(
            theme,
            'Neither of you will be matched together on future trip requests.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Block User',
          isLoading: _isSubmitting,
          variant: AppButtonVariant.primary,
          onPressed: _blockUser,
        ),
      ],
    );
  }

  Widget _bulletPoint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: theme.colorScheme.primary)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
