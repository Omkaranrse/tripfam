import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../chats/data/chat_repository.dart';
import '../data/safety_repository.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final Set<String> _unblockingIds = {};

  Future<void> _unblock(String userId) async {
    setState(() => _unblockingIds.add(userId));

    try {
      await ref.read(safetyRepositoryProvider).unblockUser(userId);
      ref.invalidate(blockedUsersListProvider);
      ref.invalidate(blockedUsersProvider);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('User unblocked.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unblock: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _unblockingIds.remove(userId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final blockedAsync = ref.watch(blockedUsersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body: blockedAsync.when(
        loading: () => const LoadingView(message: 'Loading blocked users...'),
        error: (err, _) => ErrorView(
          message: 'Unable to load blocked users list.',
          onRetry: () => ref.invalidate(blockedUsersListProvider),
        ),
        data: (blockedList) {
          if (blockedList.isEmpty) {
            return const EmptyState(
              title: 'No blocked users',
              message: 'Anyone you block from trip chats or requests will be listed here. You can unblock them at any time.',
              icon: Icons.shield_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: blockedList.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = blockedList[index];
              final isProcessing = _unblockingIds.contains(user.blockedId);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.person_off_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: Text(
                  user.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: user.blockedAt != null
                    ? Text(
                        'Blocked on ${user.blockedAt!.day}/${user.blockedAt!.month}/${user.blockedAt!.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                        ),
                      )
                    : null,
                trailing: isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton(
                        onPressed: () => _unblock(user.blockedId),
                        child: const Text('Unblock'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
