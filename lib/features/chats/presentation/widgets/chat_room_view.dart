import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/destination_image.dart';
import '../../../trips/data/trip_repository.dart';
import '../../../trips/domain/trip.dart';
import '../../domain/chat_grouped_item.dart';
import '../controllers/chat_room_controller.dart';
import 'chat_composer.dart';
import 'chat_message_bubble.dart';
import 'chat_status_dividers.dart';
import 'chat_trip_info_sheet.dart';

class ChatRoomView extends ConsumerStatefulWidget {
  const ChatRoomView({
    required this.tripId,
    this.tripTitle,
    this.destination,
    this.onBackPressed,
    this.isReadOnly = false,
    super.key,
  });

  final String tripId;
  final String? tripTitle;
  final String? destination;
  final VoidCallback? onBackPressed;
  final bool isReadOnly;

  @override
  ConsumerState<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends ConsumerState<ChatRoomView> {
  final _scrollController = ScrollController();
  bool _isNearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // In a reverse list, offset 0 is the bottom
    final isAtBottom = _scrollController.offset <= 80.0;
    if (isAtBottom != _isNearBottom) {
      setState(() => _isNearBottom = isAtBottom);
      if (isAtBottom) {
        ref.read(chatRoomControllerProvider(widget.tripId).notifier)
            .resetScrolledUpNewMessages();
      }
    }

    // When scrolled near the top of the scrollable (which is older messages)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 150.0) {
      ref.read(chatRoomControllerProvider(widget.tripId).notifier).loadEarlier();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    ref.read(chatRoomControllerProvider(widget.tripId).notifier)
        .resetScrolledUpNewMessages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roomState = ref.watch(chatRoomControllerProvider(widget.tripId));
    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));

    final trip = tripAsync.value;
    final title = widget.tripTitle ?? trip?.destination ?? 'Trip Group Chat';
    final destination = widget.destination ?? trip?.destination ?? '';
    final memberCount = trip?.confirmedMembersCount ?? 3;
    final subtitle = '$memberCount members · $destination';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // 1. Room Header
          _buildHeader(
            context,
            title: title,
            subtitle: subtitle,
            destination: destination,
            isReconnecting: roomState.isReconnecting,
          ),

          // 2. Reconnecting Pill (shown under header only when connection drops)
          if (roomState.isReconnecting) ...[
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reconnecting...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // 3. Optional Collapsible Pinned Trip Card
          if (trip != null) ...[
            _buildPinnedCard(context, trip, roomState.isPinnedCardCollapsed),
          ],

          // 4. Message List or States
          Expanded(
            child: Stack(
              children: [
                if (roomState.isLoadingInitial)
                  const Center(child: CircularProgressIndicator.adaptive())
                else if (roomState.errorMessage != null)
                  _buildErrorState(context, roomState.errorMessage!)
                else if (roomState.displayItems.isEmpty)
                  _buildEmptyState(context)
                else
                  _buildMessageList(context, roomState.displayItems),

                // Floating "New messages" pill when scrolled up
                if (!_isNearBottom &&
                    roomState.newMessagesCountWhileScrolledUp > 0)
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingActionButton.extended(
                        heroTag: 'scroll_to_bottom_pill',
                        elevation: 4,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        onPressed: _scrollToBottom,
                        icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                        label: Text(
                          '${roomState.newMessagesCountWhileScrolledUp} new messages',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 5. Typing Indicator
          ChatTypingIndicator(typingUsers: roomState.typingUsers),

          // 6. Composer
          ChatComposer(
            isReadOnly: widget.isReadOnly || (trip?.isPast ?? false),
            onSend: (text) => ref
                .read(chatRoomControllerProvider(widget.tripId).notifier)
                .send(text),
            onTyping: () => ref
                .read(chatRoomControllerProvider(widget.tripId).notifier)
                .broadcastTyping(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String destination,
    required bool isReconnecting,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(40),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // Back Button (if provided)
              if (widget.onBackPressed != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back to conversations',
                  onPressed: widget.onBackPressed,
                ),

              const SizedBox(width: 4),

              // Small Trip Photo Avatar (36px)
              ClipOval(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: DestinationImage(
                    tripId: widget.tripId,
                    destination: destination.isNotEmpty ? destination : title,
                    width: 38,
                    height: 38,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Title and Subtitle (Tap opens Trip Info sheet)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => ChatTripInfoSheet.show(
                    context,
                    tripId: widget.tripId,
                    tripTitle: title,
                    destination: destination,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Info Sheet Button
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                tooltip: 'Trip information',
                onPressed: () => ChatTripInfoSheet.show(
                  context,
                  tripId: widget.tripId,
                  tripTitle: title,
                  destination: destination,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedCard(
    BuildContext context,
    Trip trip,
    bool isCollapsed,
  ) {
    final theme = Theme.of(context);
    final datesStr =
        '${trip.startDate.day}/${trip.startDate.month} – ${trip.endDate.day}/${trip.endDate.month}';
    final meetingPoint = trip.meetingPoint.isNotEmpty
        ? trip.meetingPoint
        : 'Meeting point confirmed prior to departure';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(35),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ref
              .read(chatRoomControllerProvider(widget.tripId).notifier)
              .togglePinnedCard(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Trip Details & Meeting Point',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                  ],
                ),
                if (!isCollapsed) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        datesStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meetingPoint,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withAlpha(180),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(
    BuildContext context,
    List<ChatListItem> displayItems,
  ) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];

        if (item is ChatDaySeparatorItem) {
          return ChatDaySeparator(label: item.label);
        } else if (item is ChatUnreadDividerItem) {
          return const ChatUnreadDivider();
        } else if (item is ChatSystemMessageItem) {
          return ChatSystemMessageTile(content: item.message.content);
        } else if (item is ChatMessageBubbleItem) {
          return ChatMessageBubble(
            item: item,
            onRetry: () => ref
                .read(chatRoomControllerProvider(widget.tripId).notifier)
                .retry(item.message.clientId ?? item.message.id),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Say hello to your fellow travel companions and start planning your journey!',
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
            Icon(Icons.wifi_off_rounded, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Unable to load conversation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(160)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref
                  .read(chatRoomControllerProvider(widget.tripId).notifier)
                  .loadInitial(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
