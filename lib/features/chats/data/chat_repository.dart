import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/chat_message.dart';

/// Cryptographically secure RFC-4122 version 4 UUID generator
String generateClientUuid() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40; // Version 4
  values[8] = (values[8] & 0x3f) | 0x80; // Variant 10xx
  final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

abstract interface class ChatRepository {
  Future<List<TripChatGroup>> getUnlockedChats();

  Future<void> markChatRead(String tripId);

  Future<List<ChatMessage>> getMessages(
    String tripId, {
    DateTime? before,
    int limit = 30,
  });

  Future<ChatMessage> sendMessage(
    String tripId,
    String content, {
    String? tempId,
    String? clientId,
  });

  Future<void> sendTyping(String tripId, String userName);

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

  RealtimeChannel subscribeToTyping(
    String tripId, {
    required void Function(String userName) onUserTyping,
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
    client_id,
    kind,
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
      // First attempt to call the enhanced chat_list_summary RPC
      final summaryResponse =
          await _client.rpc<dynamic>('chat_list_summary');
      final summaryList = summaryResponse as List<dynamic>?;
      if (summaryList != null && summaryList.isNotEmpty) {
        return summaryList
            .map((item) => TripChatGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Fall through to fallback RPC if chat_list_summary is not yet migrated
    }

    try {
      final response =
          await _client.rpc<dynamic>('get_unlocked_trip_chats');
      final list = response as List<dynamic>? ?? const [];
      return list
          .map((item) => TripChatGroup.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return DemoChats.unlockedTripChats;
    }
  }

  @override
  Future<void> markChatRead(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return;
    }
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.rpc<dynamic>('mark_chat_read', params: {'p_trip_id': tripId});
    } catch (_) {
      // Fallback direct upsert
      try {
        await _client.from('chat_reads').upsert({
          'user_id': user.id,
          'trip_id': tripId,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (_) {}
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
      return DemoChats.getMessages(tripId);
    }
  }

  @override
  Future<ChatMessage> sendMessage(
    String tripId,
    String content, {
    String? tempId,
    String? clientId,
  }) async {
    final effectiveClientId = clientId ?? tempId ?? generateClientUuid();

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
            'client_id': effectiveClientId,
            'kind': 'user',
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
      if (err.contains('idx_messages_trip_sender_client_id')) {
        // Idempotent duplicate insert caught by client_id constraint: fetch the existing message
        final existing = await _client
            .from('messages')
            .select(_messageProjection)
            .eq('trip_id', tripId)
            .eq('client_id', effectiveClientId)
            .maybeSingle();
        if (existing != null) {
          return ChatMessage.fromJson(existing);
        }
      }
      throw Exception('Failed to send message. Please retry.');
    }
  }

  @override
  Future<void> sendTyping(String tripId, String userName) async {
    if (_client == null || DemoData.enabled) return;

    try {
      final channelName = 'typing:$tripId';
      final channel = _client.channel(channelName);
      await channel.sendBroadcastMessage(
        event: 'user_typing',
        payload: {
          'user_name': ChatMessage.formatDisplayName(userName),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      // Ephemeral typing indicators fail silently
    }
  }

  @override
  RealtimeChannel subscribeToTyping(
    String tripId, {
    required void Function(String userName) onUserTyping,
  }) {
    if (_client == null) {
      throw StateError('Cannot subscribe to typing without a Supabase client.');
    }

    final channelName = 'typing:$tripId';
    final channel = _client.channel(channelName);

    channel
        .onBroadcast(
          event: 'user_typing',
          callback: (payload) {
            final userName = payload['user_name'] as String?;
            if (userName != null && userName.isNotEmpty) {
              onUserTyping(userName);
            }
          },
        )
        .subscribe();

    return channel;
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
