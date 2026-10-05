import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';
import 'widgets/conversation_pane.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  TripChatGroup? _selectedChat;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatSnippetTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = context.isCompact;
    final chatsAsync = ref.watch(unlockedChatsProvider);

    return Scaffold(
      body: chatsAsync.when(
        loading: () =>
            const LoadingView(message: 'Loading active conversations...'),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Failed to load chats',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your connection and try again.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withAlpha(160),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(unlockedChatsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (chats) {
          final filteredChats = chats.where((c) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return c.tripTitle.toLowerCase().contains(query) ||
                c.destination.toLowerCase().contains(query);
          }).toList();

          // Auto-select first chat on wide screen if none selected yet
          if (!isCompact && _selectedChat == null && filteredChats.isNotEmpty) {
            _selectedChat = filteredChats.first;
          }

          if (isCompact) {
            // PHONE / COMPACT LAYOUT: Separate list view navigating to conversation screen
            return _buildListView(
              context,
              filteredChats,
              isCompact: true,
              onChatSelected: (chat) {
                context.push(
                  '/chats/${chat.tripId}',
                  extra: {
                    'title': chat.tripTitle,
                    'destination': chat.destination,
                  },
                );
              },
            );
          }

          // TABLET & WEB LAYOUT: Master-Detail view
          return Row(
            children: [
              SizedBox(
                width: 360,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: _buildListView(
                    context,
                    filteredChats,
                    isCompact: false,
                    selectedTripId: _selectedChat?.tripId,
                    onChatSelected: (chat) {
                      setState(() => _selectedChat = chat);
                    },
                  ),
                ),
              ),
              Expanded(
                child: _selectedChat != null
                    ? ConversationPane(
                        key: ValueKey(_selectedChat!.tripId),
                        tripId: _selectedChat!.tripId,
                        tripTitle: _selectedChat!.tripTitle,
                        destination: _selectedChat!.destination,
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: theme.colorScheme.primary.withAlpha(150),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a conversation',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose a trip group chat on the left to start messaging.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  160,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<TripChatGroup> chats, {
    required bool isCompact,
    String? selectedTripId,
    required void Function(TripChatGroup chat) onChatSelected,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Screen Header & Search Bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.pagePadding(context),
            16,
            AppSpacing.pagePadding(context),
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trip Chats',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh conversations',
                    onPressed: () => ref.invalidate(unlockedChatsProvider),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search chats or destinations...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withAlpha(120),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List Content
        Expanded(
          child: chats.isEmpty
              ? RefreshIndicator(
                  onRefresh: () async => ref.invalidate(unlockedChatsProvider),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 48,
                    ),
                    child: EmptyState(
                      title: _searchQuery.isNotEmpty
                          ? 'No matching chats'
                          : 'No conversations yet',
                      message: _searchQuery.isNotEmpty
                          ? 'Try searching with a different keyword.'
                          : 'Chat unlocks automatically once both you and the trip host mutually confirm your intro call.',
                      icon: Icons.chat_bubble_outline_rounded,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(unlockedChatsProvider),
                  child: ListView.separated(
                    itemCount: chats.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isSelected =
                          !isCompact && chat.tripId == selectedTripId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: theme.colorScheme.primaryContainer
                            .withAlpha(90),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.groups_rounded,
                            color: isSelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat.tripTitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.lastMessageAt != null)
                              Text(
                                _formatSnippetTime(chat.lastMessageAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    140,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              chat.destination,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              chat.lastMessage ?? 'No messages yet. Say hello!',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  160,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        onTap: () => onChatSelected(chat),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
