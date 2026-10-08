import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tripfam/features/account/data/auth_repository.dart';
import 'package:tripfam/features/account/data/profile_repository.dart';
import 'package:tripfam/features/account/domain/user_profile.dart';
import 'package:tripfam/features/chats/data/chat_repository.dart';
import 'package:tripfam/features/chats/domain/chat_message.dart';
import 'package:tripfam/features/chats/presentation/controllers/chat_room_controller.dart';

class FakeChatRepository extends Fake implements ChatRepository {
  FakeChatRepository({
    this.initialMessages = const [],
    this.failOnSend = false,
  });

  final List<ChatMessage> initialMessages;
  bool failOnSend;
  final List<ChatMessage> sentMessages = [];
  final List<String> markedReadTrips = [];

  @override
  Future<List<TripChatGroup>> getUnlockedChats() async => [];

  @override
  Future<List<ChatMessage>> getMessages(
    String tripId, {
    DateTime? before,
    int limit = 30,
  }) async {
    return initialMessages;
  }

  @override
  Future<ChatMessage> sendMessage(
    String tripId,
    String content, {
    String? tempId,
    String? clientId,
  }) async {
    if (failOnSend) {
      throw Exception('Network disconnected');
    }
    final message = ChatMessage(
      id: 'server_${clientId ?? DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      senderId: 'user_123',
      content: content,
      createdAt: DateTime.now(),
      clientId: clientId,
      status: MessageSendStatus.sent,
    );
    sentMessages.add(message);
    return message;
  }

  @override
  Future<void> markChatRead(String tripId) async {
    markedReadTrips.add(tripId);
  }

  @override
  Future<void> sendTyping(String tripId, String userName) async {}

  @override
  RealtimeChannel subscribeToTyping(
    String tripId, {
    required void Function(String userName) onUserTyping,
  }) {
    return FakeRealtimeChannel();
  }

  @override
  RealtimeChannel subscribeToTripMessages(
    String tripId, {
    required void Function(ChatMessage message) onMessage,
    void Function(String messageId)? onMessageDeleted,
  }) {
    return FakeRealtimeChannel();
  }
}

class FakeRealtimeChannel extends Fake implements RealtimeChannel {
  @override
  Future<String> unsubscribe([Duration? timeout]) async => 'ok';
}

class FakeUser extends Fake implements User {
  @override
  String get id => 'user_123';

  @override
  Map<String, dynamic> get userMetadata => {'full_name': 'Omkar A.'};
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async => null;
}

void main() {
  group('ChatRoomController Tests', () {
    test('loads initial messages and marks chat as read', () async {
      final fakeRepo = FakeChatRepository(
        initialMessages: [
          ChatMessage(
            id: 'm1',
            tripId: 'trip_100',
            senderId: 'user_456',
            content: 'Hello team',
            createdAt: DateTime.now(),
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWithValue(FakeUser()),
          userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatRoomControllerProvider('trip_100'), (_, _) {});
      addTearDown(sub.close);

      final controller =
          container.read(chatRoomControllerProvider('trip_100').notifier);
      await controller.loadInitial();

      final state = container.read(chatRoomControllerProvider('trip_100'));
      expect(state.isLoadingInitial, isFalse);
      expect(state.messages.length, equals(1));
      expect(state.messages.first.content, equals('Hello team'));
      expect(fakeRepo.markedReadTrips, contains('trip_100'));
    });

    test('optimistically sends message with valid UUID client_id', () async {
      final fakeRepo = FakeChatRepository();
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWithValue(FakeUser()),
          userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatRoomControllerProvider('trip_100'), (_, _) {});
      addTearDown(sub.close);

      final controller =
          container.read(chatRoomControllerProvider('trip_100').notifier);
      await controller.loadInitial();

      await controller.send('Can we check in early?');

      final state = container.read(chatRoomControllerProvider('trip_100'));
      expect(state.messages.length, equals(1));
      final sentMsg = state.messages.first;
      expect(sentMsg.content, equals('Can we check in early?'));
      expect(sentMsg.status, equals(MessageSendStatus.sent));
      expect(sentMsg.clientId, isNotNull);
      // Valid RFC 4122 v4 UUID format check
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(uuidRegex.hasMatch(sentMsg.clientId!), isTrue);
    });

    test('transitions message to failed status when sending fails and allows retry', () async {
      final fakeRepo = FakeChatRepository(failOnSend: true);
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWithValue(FakeUser()),
          userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatRoomControllerProvider('trip_100'), (_, _) {});
      addTearDown(sub.close);

      final controller =
          container.read(chatRoomControllerProvider('trip_100').notifier);
      await controller.loadInitial();

      await controller.send('Failing message');

      var state = container.read(chatRoomControllerProvider('trip_100'));
      expect(state.messages.length, equals(1));
      expect(state.messages.first.status, equals(MessageSendStatus.failed));

      // Now recover network and retry
      fakeRepo.failOnSend = false;
      await controller.retry(state.messages.first.clientId!);

      state = container.read(chatRoomControllerProvider('trip_100'));
      expect(state.messages.first.status, equals(MessageSendStatus.sent));
    });

    test('enforces client-side rate limit (max 5 sends in 5 seconds)', () async {
      final fakeRepo = FakeChatRepository();
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWithValue(FakeUser()),
          userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(chatRoomControllerProvider('trip_100'), (_, _) {});
      addTearDown(sub.close);

      final controller =
          container.read(chatRoomControllerProvider('trip_100').notifier);
      await controller.loadInitial();

      // Send 5 messages in quick succession
      for (var i = 0; i < 5; i++) {
        await controller.send('Rapid message $i');
      }

      // 6th message should be blocked by rate-limiter
      expect(
        () => controller.send('Rapid message 6'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('slow down'),
          ),
        ),
      );
    });
  });
}
