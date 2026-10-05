import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/chat_message.dart';

abstract interface class ChatRepository {
  Future<List<TripChatGroup>> getUnlockedChats();

  Future<List<ChatMessage>> getMessages(
    String tripId, {
    DateTime? before,
    int limit = 30,
  });

  Future<ChatMessage> sendMessage(
    String tripId,
    String content, {
    String? tempId,
  });

  Future<void> blockUser(String userId);

  Future<void> unblockUser(String userId);

  Future<void> reportUser(
    String userId, {
    required String reason,
    required String details,
    String? tripId,
  });

  Future<Set<String>> getBlockedUserIds();

  RealtimeChannel subscribeToTripMessages(
    String tripId, {
    required void Function(ChatMessage message) onMessage,
    void Function(String messageId)? onMessageDeleted,
  });
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient? _client;

  static const String _messageProjection = '''
    id,
    trip_id,
    sender_id,
    content,
    created_at,
    updated_at,
    sender_profile:profiles!messages_sender_id_fkey(
      id,
      display_name,
      avatar_path
    )
  ''';

  @override
  Future<List<TripChatGroup>> getUnlockedChats() async {
    if (_client == null || DemoData.enabled) {
      return DemoChats.unlockedTripChats;
    }
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await _client.rpc<dynamic>('get_unlocked_trip_chats');
      final list = response as List<dynamic>? ?? const [];
      return list
          .map((item) => TripChatGroup.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String tripId, {
    DateTime? before,
    int limit = 30,
  }) async {
    if (_client == null || DemoData.enabled) {
      return DemoChats.getMessages(tripId);
    }

    try {
      var query = _client
          .from('messages')
          .select(_messageProjection)
          .eq('trip_id', tripId);

      if (before != null) {
        query = query.lt('created_at', before.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (response as List<dynamic>)
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();

      // Return chronological order (oldest to newest)
      return list.reversed.toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ChatMessage> sendMessage(
    String tripId,
    String content, {
    String? tempId,
  }) async {
    if (_client == null || DemoData.enabled) {
      return DemoChats.sendMessage(tripId, content);
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be signed in.');
    }

    // Security: Validate and sanitize (never log the actual message content)
    final sanitized = ChatMessage.validateAndSanitize(content);

    try {
      final response = await _client
          .from('messages')
          .insert({
            'trip_id': tripId,
            'sender_id': user.id,
            'content': sanitized,
          })
          .select(_messageProjection)
          .single();

      return ChatMessage.fromJson(response);
    } catch (e) {
      final err = e.toString();
      if (err.contains('42501') || err.contains('policy')) {
        throw Exception(
          'Message not allowed: You must be a confirmed trip member with an unlocked chat to message.',
        );
      }
      throw Exception('Failed to send message. Please retry.');
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    if (_client == null) {
      throw Exception('Authentication required to block a user.');
    }

    try {
      await _client.rpc<dynamic>(
        'block_user',
        params: {'p_blocked_id': userId},
      );
    } catch (e) {
      throw Exception('Unable to block user: ${e.toString()}');
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (_client == null) {
      throw Exception('Authentication required to unblock a user.');
    }

    try {
      await _client.rpc<dynamic>(
        'unblock_user',
        params: {'p_blocked_id': userId},
      );
    } catch (e) {
      throw Exception('Unable to unblock user: ${e.toString()}');
    }
  }

  @override
  Future<void> reportUser(
    String userId, {
    required String reason,
    required String details,
    String? tripId,
  }) async {
    if (_client == null) {
      throw Exception('Authentication required to report a user.');
    }

    final cleanReason = TextSanitizer.limit(reason, 100);
    final cleanDetails = TextSanitizer.limit(details, 2000);

    try {
      await _client.rpc<dynamic>(
        'report_user',
        params: {
          'p_reported_user_id': userId,
          'p_reason': cleanReason,
          'p_details': cleanDetails,
          'p_trip_id': tripId,
        },
      );
    } catch (e) {
      throw Exception('Unable to submit report: ${e.toString()}');
    }
  }

  @override
  Future<Set<String>> getBlockedUserIds() async {
    if (_client == null) return const {};
    final user = _client.auth.currentUser;
    if (user == null) return const {};

    try {
      final response = await _client
          .from('blocks')
          .select('blocked_id')
          .eq('blocker_id', user.id);

      final list = response as List<dynamic>;
      return list.map((item) => item['blocked_id'] as String).toSet();
    } catch (_) {
      return const {};
    }
  }

  @override
  RealtimeChannel subscribeToTripMessages(
    String tripId, {
    required void Function(ChatMessage message) onMessage,
    void Function(String messageId)? onMessageDeleted,
  }) {
    if (_client == null) {
      throw StateError(
        'Cannot subscribe to realtime without a Supabase client.',
      );
    }

    final channelName = 'public:messages:trip_id=$tripId';
    final channel = _client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) async {
            try {
              final newRow = payload.newRecord;
              final messageId = newRow['id'] as String;

              // Fetch sender profile securely
              final fullData = await _client
                  .from('messages')
                  .select(_messageProjection)
                  .eq('id', messageId)
                  .maybeSingle();

              if (fullData != null) {
                onMessage(ChatMessage.fromJson(fullData));
              } else {
                onMessage(ChatMessage.fromJson(newRow));
              }
            } catch (_) {
              // Realtime errors should fail silently without crashing
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (payload) {
            final oldRow = payload.oldRecord;
            final messageId = oldRow['id'] as String?;
            if (messageId != null && onMessageDeleted != null) {
              onMessageDeleted(messageId);
            }
          },
        )
        .subscribe();

    return channel;
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseChatRepository(client);
});

final unlockedChatsProvider = FutureProvider<List<TripChatGroup>>((ref) {
  return ref.watch(chatRepositoryProvider).getUnlockedChats();
});

final blockedUsersProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(chatRepositoryProvider).getBlockedUserIds();
});
