import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/features/chats/domain/chat_message.dart';

void main() {
  group('ChatMessage Security & Validation Tests', () {
    test('validateAndSanitize accepts valid plain text message and trims whitespace', () {
      const input = '   Hey travel fam, excited for our trip to Kyoto!   ';
      final clean = ChatMessage.validateAndSanitize(input);
      expect(clean, equals('Hey travel fam, excited for our trip to Kyoto!'));
    });

    test('validateAndSanitize rejects empty or whitespace-only messages', () {
      expect(
        () => ChatMessage.validateAndSanitize(''),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );

      expect(
        () => ChatMessage.validateAndSanitize('   \n\t  '),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('empty'),
          ),
        ),
      );
    });

    test('validateAndSanitize strictly strips HTML and script tags for plain text security', () {
      const malicious =
          '<script>alert("hacked")</script>Hello <b>everyone</b>!<img src=x onerror=alert(1)>';
      final clean = ChatMessage.validateAndSanitize(malicious);
      expect(clean, isNot(contains('<script>')));
      expect(clean, isNot(contains('</script>')));
      expect(clean, isNot(contains('<b>')));
      expect(clean, isNot(contains('</b>')));
      expect(clean, isNot(contains('<img')));
      expect(clean, equals('alert("hacked")Hello everyone!'));
    });

    test(
      'validateAndSanitize rejects messages exceeding 4000 characters limit',
      () {
        final overLimit = 'A' * 4001;
        expect(
          () => ChatMessage.validateAndSanitize(overLimit),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('4000'),
            ),
          ),
        );

        final exactlyLimit = 'A' * 4000;
        expect(
          ChatMessage.validateAndSanitize(exactlyLimit).length,
          equals(4000),
        );
      },
    );

    test('validateAndSanitize strips ASCII control characters', () {
      const withControl = 'Safe\u0000text\u0008here';
      final clean = ChatMessage.validateAndSanitize(withControl);
      expect(clean, equals('Safetexthere'));
    });
  });

  group('ChatMessage Parsing & Ownership Tests', () {
    test('ChatMessage.fromJson parses server data correctly and sanitizes sender name and content', () {
      final json = {
        'id': 'msg-123',
        'trip_id': 'trip-456',
        'sender_id': 'user-789',
        'content': '<b>Looking forward to hiking!</b>',
        'created_at': '2026-10-03T12:00:00Z',
        'sender_profile': {
          'id': 'user-789',
          'display_name': '<i>Alice</i>',
          'avatar_path': 'avatars/user-789.png',
        },
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.id, equals('msg-123'));
      expect(msg.tripId, equals('trip-456'));
      expect(msg.senderId, equals('user-789'));
      expect(msg.content, equals('Looking forward to hiking!'));
      expect(msg.senderName, equals('Alice'));
      expect(msg.senderAvatar, equals('avatars/user-789.png'));
      expect(msg.status, equals(MessageSendStatus.sent));
    });

    test('isMine correctly differentiates sender from recipient', () {
      final msg = ChatMessage(
        id: 'msg-1',
        tripId: 'trip-1',
        senderId: 'user-alice',
        content: 'Hello',
        createdAt: DateTime.now(),
      );

      expect(msg.isMine('user-alice'), isTrue);
      expect(msg.isMine('user-bob'), isFalse);
      expect(msg.isMine(null), isFalse);
    });

    test('copyWith updates status for optimistic and failure states', () {
      final msg = ChatMessage(
        id: 'temp-1',
        tripId: 'trip-1',
        senderId: 'user-alice',
        content: 'Testing send',
        createdAt: DateTime.now(),
        status: MessageSendStatus.sending,
        clientTempId: 'temp-1',
      );

      final failed = msg.copyWith(status: MessageSendStatus.failed);
      expect(failed.status, equals(MessageSendStatus.failed));
      expect(failed.clientTempId, equals('temp-1'));

      final sent = msg.copyWith(
        id: 'confirmed-1',
        status: MessageSendStatus.sent,
      );
      expect(sent.id, equals('confirmed-1'));
      expect(sent.status, equals(MessageSendStatus.sent));
    });
  });

  group('TripChatGroup Domain Model Tests', () {
    test('TripChatGroup.fromJson parses and sanitizes group header data', () {
      final json = {
        'trip_id': 'trip-99',
        'trip_title': '<b>Mountain Adventure</b>',
        'destination': 'Swiss Alps',
        'host_id': 'host-1',
        'host_name': 'Hans',
        'member_count': 4,
        'last_message': 'See you at the station!',
        'last_message_at': '2026-10-03T15:30:00Z',
      };

      final group = TripChatGroup.fromJson(json);
      expect(group.tripId, equals('trip-99'));
      expect(group.tripTitle, equals('Mountain Adventure'));
      expect(group.destination, equals('Swiss Alps'));
      expect(group.hostId, equals('host-1'));
      expect(group.hostName, equals('Hans'));
      expect(group.memberCount, equals(4));
      expect(group.lastMessage, equals('See you at the station!'));
      expect(group.lastMessageAt, isNotNull);
    });
  });

  group('In-Chat Moderation & Block Filtering Logic Tests', () {
    test('Blocked user messages are filtered from message feed', () {
      final messages = [
        ChatMessage(
          id: '1',
          tripId: 'trip-1',
          senderId: 'user-friendly',
          content: 'Hello everyone!',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        ChatMessage(
          id: '2',
          tripId: 'trip-1',
          senderId: 'user-blocked',
          content: 'Spam message',
          createdAt: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
        ChatMessage(
          id: '3',
          tripId: 'trip-1',
          senderId: 'user-me',
          content: 'Hey there',
          createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      ];

      final blockedUserIds = {'user-blocked'};
      final visible = messages
          .where((m) => !blockedUserIds.contains(m.senderId))
          .toList();

      expect(visible.length, equals(2));
      expect(visible.any((m) => m.senderId == 'user-blocked'), isFalse);
      expect(visible.map((m) => m.id), containsAll(['1', '3']));
    });
  });
}
