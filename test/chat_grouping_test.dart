import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/features/chats/domain/chat_grouped_item.dart';
import 'package:tripfam/features/chats/domain/chat_message.dart';

void main() {
  group('ChatGroupingEngine & Privacy Tests', () {
    test('formats display names safely as First Name + Last Initial', () {
      expect(
        ChatMessage.formatDisplayName('Aarav Patel'),
        equals('Aarav P.'),
      );
      expect(
        ChatMessage.formatDisplayName('Sneha'),
        equals('Sneha'),
      );
      // Privacy: Never exposes email address
      expect(
        ChatMessage.formatDisplayName('aarav.patel@example.com'),
        equals('aarav.patel'),
      );
      // Privacy: Pure phone numbers return generic 'Traveller'
      expect(
        ChatMessage.formatDisplayName('+91 98765 43210'),
        equals('Traveller'),
      );
      // Fallback
      expect(
        ChatMessage.formatDisplayName(null),
        equals('Fellow Traveller'),
      );
      expect(
        ChatMessage.formatDisplayName('   '),
        equals('Fellow Traveller'),
      );
    });

    test('groups consecutive messages from same sender within 5 minutes', () {
      final baseTime = DateTime(2026, 10, 7, 10, 0);
      final messages = [
        ChatMessage(
          id: '1',
          tripId: 'trip_1',
          senderId: 'user_a',
          senderName: 'Aarav Patel',
          content: 'Hey everyone!',
          createdAt: baseTime,
        ),
        ChatMessage(
          id: '2',
          tripId: 'trip_1',
          senderId: 'user_a',
          senderName: 'Aarav Patel',
          content: 'Are we still meeting at the gate?',
          createdAt: baseTime.add(const Duration(minutes: 2)),
        ),
        ChatMessage(
          id: '3',
          tripId: 'trip_1',
          senderId: 'user_b',
          senderName: 'Priya Sharma',
          content: 'Yes, 9 AM sharp!',
          createdAt: baseTime.add(const Duration(minutes: 3)),
        ),
      ];

      final items = ChatGroupingEngine.buildDisplayItems(
        messages: messages,
        currentUserId: 'me',
        unreadCountOnOpen: 0,
      );

      // Items are returned reversed for ListView(reverse: true). Reverse to test chronologically.
      final bubbles =
          items.whereType<ChatMessageBubbleItem>().toList().reversed.toList();
      expect(bubbles.length, equals(3));

      // Bubble 1: first in group from user_a -> show avatar and name
      expect(bubbles[0].message.id, equals('1'));
      expect(bubbles[0].isFirstInGroup, isTrue);
      expect(bubbles[0].isLastInGroup, isFalse);
      expect(bubbles[0].showSenderHeader, isTrue);
      expect(bubbles[0].gapBelow, equals(2.0));

      // Bubble 2: second in group from user_a -> hides avatar and name
      expect(bubbles[1].message.id, equals('2'));
      expect(bubbles[1].isFirstInGroup, isFalse);
      expect(bubbles[1].isLastInGroup, isTrue);
      expect(bubbles[1].showSenderHeader, isFalse);
      expect(bubbles[1].gapBelow, equals(12.0));

      // Bubble 3: different sender (user_b) -> new group
      expect(bubbles[2].message.id, equals('3'));
      expect(bubbles[2].isFirstInGroup, isTrue);
      expect(bubbles[2].isLastInGroup, isTrue);
      expect(bubbles[2].showSenderHeader, isTrue);
    });

    test('breaks group if messages from same sender exceed 5 minutes apart', () {
      final baseTime = DateTime(2026, 10, 7, 10, 0);
      final messages = [
        ChatMessage(
          id: '1',
          tripId: 'trip_1',
          senderId: 'user_a',
          senderName: 'Aarav Patel',
          content: 'Morning!',
          createdAt: baseTime,
        ),
        ChatMessage(
          id: '2',
          tripId: 'trip_1',
          senderId: 'user_a',
          senderName: 'Aarav Patel',
          content: 'Anyone there?',
          createdAt: baseTime.add(const Duration(minutes: 6)), // > 5 mins
        ),
      ];

      final items = ChatGroupingEngine.buildDisplayItems(
        messages: messages,
        currentUserId: 'me',
        unreadCountOnOpen: 0,
      );

      final bubbles =
          items.whereType<ChatMessageBubbleItem>().toList().reversed.toList();
      expect(bubbles[0].isLastInGroup, isTrue);
      expect(bubbles[0].gapBelow, equals(12.0));
      expect(bubbles[1].isFirstInGroup, isTrue);
      expect(bubbles[1].showSenderHeader, isTrue);
    });

    test('inserts day separators and unread divider accurately', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final messages = [
        ChatMessage(
          id: '1',
          tripId: 'trip_1',
          senderId: 'user_a',
          senderName: 'Aarav Patel',
          content: 'Yesterday message',
          createdAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 14, 0),
        ),
        ChatMessage(
          id: '2',
          tripId: 'trip_1',
          senderId: 'user_b',
          senderName: 'Priya Sharma',
          content: 'Unread message today',
          createdAt: DateTime(now.year, now.month, now.day, 9, 0),
        ),
      ];

      final items = ChatGroupingEngine.buildDisplayItems(
        messages: messages,
        currentUserId: 'me',
        unreadCountOnOpen: 1, // 1 unread message
      );

      // Should contain day separator for yesterday, message 1, day separator for today, unread divider, message 2
      final daySeparators =
          items.whereType<ChatDaySeparatorItem>().toList().reversed.toList();
      expect(daySeparators.length, equals(2));
      expect(daySeparators[0].label, equals('Yesterday'));
      expect(daySeparators[1].label, equals('Today'));

      final unreadDividers = items.whereType<ChatUnreadDividerItem>().toList();
      expect(unreadDividers.length, equals(1));
    });

    test('renders system messages as distinct system items', () {
      final now = DateTime.now();
      final messages = [
        ChatMessage(
          id: 'sys_1',
          tripId: 'trip_1',
          senderId: 'system',
          content: 'Priya Sharma joined the trip!',
          createdAt: now,
          kind: MessageKind.system,
        ),
      ];

      final items = ChatGroupingEngine.buildDisplayItems(
        messages: messages,
        currentUserId: 'me',
        unreadCountOnOpen: 0,
      );

      final systemItems = items.whereType<ChatSystemMessageItem>().toList();
      expect(systemItems.length, equals(1));
      expect(systemItems.first.message.content, equals('Priya Sharma joined the trip!'));
    });
  });
}
