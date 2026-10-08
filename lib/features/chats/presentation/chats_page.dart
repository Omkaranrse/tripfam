import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/breakpoints.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../domain/chat_message.dart';
import 'controllers/chat_list_controller.dart';
import 'widgets/chat_room_view.dart';

class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key});

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  TripChatGroup? _selectedChat;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatSmartTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(dt.year, dt.month, dt.day);

    if (msgDate == today) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(dt).inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[dt.weekday - 1];
    } else {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString().substring(2);
      return '$day/$month/$year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = context.isCompact;
    final listState = ref.watch(chatListControllerProvider);

    // Auto-select first upcoming chat on wide screen if none selected yet
    if (!isCompact &&
        _selectedChat == null &&
        listState.upcomingChats.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedChat == null) {
          setState(() {
            _selectedChat = listState.upcomingChats.first;
          });
        }
      });
    }

    if (isCompact) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: _buildListPane(context, listState, isMasterDetail: false),
      );
    }

    // Tablet & Web Master-Detail Layout
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          // Left Master List (360-420px wide)
          SizedBox(
            width: 380,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outline.withAlpha(40),
                    width: 1.0,
                  ),
                ),
              ),
              child: _buildListPane(context, listState, isMasterDetail: true),
            ),
          ),

          // Right Detail Room / Placeholder
          Expanded(
            child: _selectedChat != null
                ? ChatRoomView(
                    key: ValueKey(_selectedChat!.tripId),
                    tripId: _selectedChat!.tripId,
                    tripTitle: _selectedChat!.tripTitle,
                    destination: _selectedChat!.destination,
                    isReadOnly: _selectedChat!.isPast,
                    onBackPressed: null, // No back button on master-detail
                  )
                : _buildMasterDetailPlaceholder(context),
          ),
        ],
      ),
    );
  }

  Widget _buildListPane(
    BuildContext context,
    ChatListState state, {
    required bool isMasterDetail,
  }) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(chatListControllerProvider.notifier).loadChats(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header & Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trip Chats',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Bar with local title & destination filtering
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => ref
                        .read(chatListControllerProvider.notifier)
                        .setSearchQuery(val),
                    decoration: InputDecoration(
                      hintText: 'Search chats or destinations...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(130),
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: state.searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                ref
                                    .read(chatListControllerProvider.notifier)
                                    .setSearchQuery('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(80),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content States
          if (state.isLoading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildSkeletonLoader(context),
            )
          else if (state.errorMessage != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState(context, state.errorMessage!),
            )
          else if (state.filteredChats.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context, isSearch: state.searchQuery.isNotEmpty),
            )
          else
            _buildGroupedChatList(context, state, isMasterDetail: isMasterDetail),
        ],
      ),
    );
  }

  Widget _buildGroupedChatList(
    BuildContext context,
    ChatListState state, {
    required bool isMasterDetail,
  }) {
    final upcoming = state.upcomingChats;
    final past = state.pastChats;

    return SliverPadding(
      // 80px bottom padding so the last row clears the nav bar!
      padding: const EdgeInsets.only(bottom: 80),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 1. Upcoming Trips Section
          if (upcoming.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              title: 'Upcoming Trips',
              count: upcoming.length,
            ),
            for (var i = 0; i < upcoming.length; i++) ...[
              _buildChatRow(
                context,
                chat: upcoming[i],
                searchQuery: state.searchQuery,
                isMasterDetail: isMasterDetail,
              ),
              if (i < upcoming.length - 1)
                const Divider(indent: 76, height: 1),
            ],
          ],

          // 2. Past Trips Section (Read-only)
          if (past.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionHeader(
              context,
              title: 'Past Trips',
              count: past.length,
              isReadOnly: true,
            ),
            for (var i = 0; i < past.length; i++) ...[
              _buildChatRow(
                context,
                chat: past[i],
                searchQuery: state.searchQuery,
                isMasterDetail: isMasterDetail,
              ),
              if (i < past.length - 1)
                const Divider(indent: 76, height: 1),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    bool isReadOnly = false,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (isReadOnly) ...[
            const Spacer(),
            Icon(
              Icons.lock_outline_rounded,
              size: 13,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
            const SizedBox(width: 4),
            Text(
              'Read-only',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatRow(
    BuildContext context, {
    required TripChatGroup chat,
    required String searchQuery,
    required bool isMasterDetail,
  }) {
    final theme = Theme.of(context);
    final hasUnread = chat.unreadCount > 0;
    final isSelected = isMasterDetail && _selectedChat?.tripId == chat.tripId;
    final timeStr = _formatSmartTimestamp(chat.lastMessageAt);

    // Format second line: "FirstName: message preview"
    String previewText = 'No messages yet';
    if (chat.lastMessage != null && chat.lastMessage!.isNotEmpty) {
      if (chat.lastSenderName != null &&
          !chat.lastMessage!.startsWith('${chat.lastSenderName}:')) {
        previewText = '${chat.lastSenderName}: ${chat.lastMessage!}';
      } else {
        previewText = chat.lastMessage!;
      }
    }

    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withAlpha(25)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          ref
              .read(chatListControllerProvider.notifier)
              .markTripRead(chat.tripId);

          if (isMasterDetail) {
            setState(() => _selectedChat = chat);
          } else {
            context.push(
              '/chats/${chat.tripId}',
              extra: {
                'title': chat.tripTitle,
                'destination': chat.destination,
              },
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 56px circular trip cover photo (with initials fallback)
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: DestinationImage(
                    tripId: chat.tripId,
                    destination: chat.destination.isNotEmpty
                        ? chat.destination
                        : chat.tripTitle,
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Title and preview columns
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: Title (16/600, ellipsis) + Smart timestamp
                    Row(
                      children: [
                        Expanded(
                          child: _buildHighlightedText(
                            text: chat.tripTitle,
                            query: searchQuery,
                            baseStyle: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                            highlightStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              backgroundColor:
                                  theme.colorScheme.primary.withAlpha(40),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Line 2: "FirstName: message preview" (14/400 muted) + Unread Pill
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            previewText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  hasUnread ? FontWeight.w600 : FontWeight.w400,
                              color: hasUnread
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface.withAlpha(150),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${chat.unreadCount}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText({
    required String text,
    required String query,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase().trim();
    final matches = lowerQuery.allMatches(lowerText).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <InlineSpan>[];
    int start = 0;

    for (final m in matches) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: highlightStyle,
        ),
      );
      start = m.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    return Column(
      children: List.generate(6, (index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SkeletonBox(width: 56, height: 56, borderRadiusValue: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 220, height: 14),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isSearch}) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearch
                    ? Icons.search_off_rounded
                    : Icons.forum_outlined,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No matching conversations' : 'No active chats yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isSearch
                  ? 'Try searching with a different trip title or destination.'
                  : 'Group chats unlock automatically once mutual intro calls with your host are completed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Failed to load chats',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(160)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  ref.read(chatListControllerProvider.notifier).loadChats(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterDetailPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 52,
                color: theme.colorScheme.primary.withAlpha(120),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Select a trip conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an upcoming or past trip from the list on the left to review messages and coordinate departure.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(160),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
