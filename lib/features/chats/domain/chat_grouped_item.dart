import 'chat_message.dart';

sealed class ChatListItem {
  const ChatListItem();
}

class ChatDaySeparatorItem extends ChatListItem {
  const ChatDaySeparatorItem({
    required this.date,
    required this.label,
  });

  final DateTime date;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatDaySeparatorItem &&
          runtimeType == other.runtimeType &&
          label == other.label;

  @override
  int get hashCode => label.hashCode;
}

class ChatUnreadDividerItem extends ChatListItem {
  const ChatUnreadDividerItem();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatUnreadDividerItem && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ChatSystemMessageItem extends ChatListItem {
  const ChatSystemMessageItem(this.message);

  final ChatMessage message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSystemMessageItem &&
          runtimeType == other.runtimeType &&
          message.id == other.message.id;

  @override
  int get hashCode => message.id.hashCode;
}

class ChatMessageBubbleItem extends ChatListItem {
  const ChatMessageBubbleItem({
    required this.message,
    required this.isMine,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.showSenderHeader,
    required this.gapBelow,
  });

  final ChatMessage message;
  final bool isMine;

  /// First message chronologically in this sender group (shows avatar + name)
  final bool isFirstInGroup;

  /// Last message chronologically in this sender group
  final bool isLastInGroup;

  /// Whether avatar and sender name should be rendered
  final bool showSenderHeader;

  /// Gap to next bubble: 2px within group, 12px between different groups
  final double gapBelow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageBubbleItem &&
          runtimeType == other.runtimeType &&
          message.id == other.message.id &&
          message.status == other.message.status &&
          message.content == other.message.content &&
          isMine == other.isMine &&
          isFirstInGroup == other.isFirstInGroup &&
          isLastInGroup == other.isLastInGroup &&
          gapBelow == other.gapBelow;

  @override
  int get hashCode => Object.hash(
        message.id,
        message.status,
        message.content,
        isMine,
        isFirstInGroup,
        gapBelow,
      );
}

abstract final class ChatGroupingEngine {
  /// Transforms chronological messages (oldest first) into display items
  /// ordered for a reverse ListView.builder (newest first).
  ///
  /// Grouping rules:
  /// - Consecutive messages from same sender within 5 minutes are grouped together.
  /// - Avatar and sender name only on the first message (oldest in group).
  /// - 2px gap between grouped bubbles, 12px between different groups.
  /// - Day separators: "Today", "Yesterday", or formatted date.
  /// - Unread divider placed before the first unread message.
  static List<ChatListItem> buildDisplayItems({
    required List<ChatMessage> messages,
    int unreadCountOnOpen = 0,
    String? currentUserId,
    DateTime? nowOverride,
  }) {
    if (messages.isEmpty) return const [];

    final now = nowOverride ?? DateTime.now();
    final itemsChronological = <ChatListItem>[];

    final unreadThresholdIndex = unreadCountOnOpen > 0
        ? (messages.length - unreadCountOnOpen).clamp(0, messages.length)
        : -1;

    DateTime? lastDate;

    for (var i = 0; i < messages.length; i++) {
      final msg = messages[i];
      final isMine = msg.isMine(currentUserId);

      // 1. Day separator check
      final msgDate = DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDate == null || msgDate != lastDate) {
        lastDate = msgDate;
        itemsChronological.add(
          ChatDaySeparatorItem(
            date: msgDate,
            label: formatDaySeparator(msgDate, now: now),
          ),
        );
      }

      // 2. Unread messages divider check
      if (unreadThresholdIndex != -1 && i == unreadThresholdIndex) {
        itemsChronological.add(const ChatUnreadDividerItem());
      }

      // 3. System messages
      if (msg.isSystem) {
        itemsChronological.add(ChatSystemMessageItem(msg));
        continue;
      }

      // 4. Consecutive grouping analysis (within 5 minutes, same sender, not system)
      final prev = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;

      final isPrevSameSender = prev != null &&
          !prev.isSystem &&
          prev.senderId == msg.senderId &&
          msg.createdAt.difference(prev.createdAt).inMinutes.abs() < 5 &&
          isSameDay(prev.createdAt, msg.createdAt);

      final isNextSameSender = next != null &&
          !next.isSystem &&
          next.senderId == msg.senderId &&
          next.createdAt.difference(msg.createdAt).inMinutes.abs() < 5 &&
          isSameDay(next.createdAt, msg.createdAt);

      final isFirstInGroup = !isPrevSameSender;
      final isLastInGroup = !isNextSameSender;

      // Avatar and name only on the first message for other users (never on own)
      final showSenderHeader = isFirstInGroup && !isMine;

      // 2px gap between grouped bubbles, 12px between different groups
      final gapBelow = isLastInGroup ? 12.0 : 2.0;

      itemsChronological.add(
        ChatMessageBubbleItem(
          message: msg,
          isMine: isMine,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          showSenderHeader: showSenderHeader,
          gapBelow: gapBelow,
        ),
      );
    }

    // Reverse list so index 0 is the newest item for reverse ListView
    return itemsChronological.reversed.toList();
  }

  static String formatDaySeparator(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final check = DateTime(date.year, date.month, date.day);

    if (check == today) {
      return 'Today';
    } else if (check == yesterday) {
      return 'Yesterday';
    } else {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[date.month - 1];
      if (date.year == current.year) {
        return '$month ${date.day}';
      }
      return '$month ${date.day}, ${date.year}';
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
