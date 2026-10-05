import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/verification_repository.dart';
import '../domain/verification_models.dart';

class AdminVerificationScreen extends ConsumerStatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  ConsumerState<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState
    extends ConsumerState<AdminVerificationScreen> {
  final Set<String> _processingIds = {};

  Future<void> _handleApprove(AdminVerificationItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve ${item.displayName}?'),
        content: const Text(
          'This will set is_verified = true on their profile, write an audit log entry, and immediately delete the verification selfie from storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(item.requestId));

    try {
      await ref
          .read(verificationRepositoryProvider)
          .approveRequest(item.requestId, notes: 'Verified by review');

      ref.invalidate(adminVerificationQueueProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '${item.displayName} has been verified and selfie purged.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Failed to approve: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(item.requestId));
      }
    }
  }

  Future<void> _handleReject(AdminVerificationItem item) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${item.displayName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a clear reason for the applicant. The selfie will be deleted after rejection.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. Face obscured by shadow, Photo too blurry',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reject & Delete Selfie'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds.add(item.requestId));

    try {
      await ref
          .read(verificationRepositoryProvider)
          .rejectRequest(item.requestId, reason: reasonController.text.trim());

      ref.invalidate(adminVerificationQueueProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification rejected for ${item.displayName}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(item.requestId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(adminVerificationQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Verification Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: () => ref.invalidate(adminVerificationQueueProvider),
          ),
        ],
      ),
      body: queueAsync.when(
        loading: () => const LoadingView(
          message: 'Loading pending verification requests...',
        ),
        error: (err, _) => ErrorView(
          message:
              'Access restricted or failed to load review queue: ${err.toString()}',
          onRetry: () => ref.invalidate(adminVerificationQueueProvider),
        ),
        data: (queue) {
          if (queue.isEmpty) {
            return const EmptyState(
              title: 'Queue is clear',
              message: 'There are no pending identity verification requests awaiting review.',
              icon: Icons.check_circle_outline_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: queue.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = queue[index];
              final isProcessing = _processingIds.contains(item.requestId);

              return _VerificationReviewCard(
                item: item,
                isProcessing: isProcessing,
                onApprove: () => _handleApprove(item),
                onReject: () => _handleReject(item),
              );
            },
          );
        },
      ),
    );
  }
}

class _VerificationReviewCard extends ConsumerWidget {
  const _VerificationReviewCard({
    required this.item,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final AdminVerificationItem item;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.createdAt != null)
                Text(
                  'Submitted ${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
            ],
          ),
          if (item.reviewerNotes != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.reviewerNotes!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Side-by-side comparison
          Row(
            children: [
              // Profile Photo
              Expanded(
                child: Column(
                  children: [
                    Text('Profile Photo', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.avatarPath != null
                          ? Image.network(
                              item.avatarPath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackIcon(theme),
                            )
                          : _fallbackIcon(theme),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Verification Selfie (via signed URL)
              Expanded(
                child: Column(
                  children: [
                    Text('Live Selfie', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    FutureBuilder<String?>(
                      future: ref
                          .read(verificationRepositoryProvider)
                          .getSignedSelfieUrl(item.selfieStoragePath),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        final signedUrl = snapshot.data;
                        if (signedUrl == null) {
                          return Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('Unable to load signed selfie'),
                            ),
                          );
                        }

                        return Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withAlpha(120),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            signedUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Actions
          if (isProcessing)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve & Verify'),
                    onPressed: onApprove,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _fallbackIcon(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.person_rounded,
        size: 56,
        color: theme.colorScheme.onSurfaceVariant.withAlpha(140),
      ),
    );
  }
}
