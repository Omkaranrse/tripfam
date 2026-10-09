import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
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

/// Adapter allowing Firestore stream subscriptions to act as a RealtimeChannel
class FirestoreRealtimeChannel implements RealtimeChannel {
  FirestoreRealtimeChannel(this._subscription);

  final StreamSubscription<dynamic>? _subscription;

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    await _subscription?.cancel();
    return 'ok';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Production Cloud Firestore real-time implementation of ChatRepository
class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  @override
  Future<List<TripChatGroup>> getUnlockedChats() async {
    final user = _auth.currentUser;
    if (user == null || DemoData.enabled) {
      return DemoChats.unlockedTripChats;
    }

    try {
      // Query trips where user is a participant or host
      final tripsQuery = await _firestore
          .collection('trips')
          .where('members', arrayContains: user.uid)
          .get();

      if (tripsQuery.docs.isEmpty) {
        // Also check if user is host of any trip
        final hostedQuery = await _firestore
            .collection('trips')
            .where('hostId', isEqualTo: user.uid)
            .get();

        if (hostedQuery.docs.isEmpty) {
          return DemoChats.unlockedTripChats;
        }
      }

      final allDocs = {
        ...tripsQuery.docs,
      };

      final groups = <TripChatGroup>[];
      for (final doc in allDocs) {
        final data = doc.data();
        final tripId = doc.id;
        final destination = (data['destination'] as String?) ?? 'Trip';

        // Check for latest message
        final latestMsgSnap = await _firestore
            .collection('chats')
            .doc(tripId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

        String? lastMessage;
        DateTime? lastMessageAt;
        if (latestMsgSnap.docs.isNotEmpty) {
          final msgData = latestMsgSnap.docs.first.data();
          lastMessage = msgData['content'] as String?;
          final rawTime = msgData['createdAt'];
          if (rawTime is Timestamp) {
            lastMessageAt = rawTime.toDate();
          }
        }

        groups.add(
          TripChatGroup(
            tripId: tripId,
            tripTitle: destination,
            destination: destination,
            hostId: (data['hostId'] as String?) ?? '',
            lastMessage: lastMessage,
            lastMessageAt: lastMessageAt,
            unreadCount: 0,
          ),
        );
      }

      return groups.isNotEmpty ? groups : DemoChats.unlockedTripChats;
    } catch (_) {
      return DemoChats.unlockedTripChats;
    }
  }

  @override
  Future<void> markChatRead(String tripId) async {
    final user = _auth.currentUser;
    if (user == null || DemoData.enabled) return;

    try {
      await _firestore
          .collection('chats')
          .doc(tripId)
          .collection('reads')
          .doc(user.uid)
          .set({
        'lastReadAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-blocking read receipt
    }
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String tripId, {
    DateTime? before,
    int limit = 30,
  }) async {
    if (DemoData.enabled) {
      return DemoChats.getMessages(tripId);
    }

    try {
      var query = _firestore
          .collection('chats')
          .doc(tripId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (before != null) {
        query = query.where(
          'createdAt',
          isLessThan: Timestamp.fromDate(before),
        );
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        return DemoChats.getMessages(tripId);
      }

      final list = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return ChatMessage.fromJson(data);
      }).toList();

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
    final user = _auth.currentUser;

    if (user == null || DemoData.enabled) {
      return DemoChats.sendMessage(tripId, content);
    }

    final sanitized = ChatMessage.validateAndSanitize(content);
    final now = DateTime.now();

    try {
      final docRef = _firestore
          .collection('chats')
          .doc(tripId)
          .collection('messages')
          .doc();

      final payload = {
        'id': docRef.id,
        'tripId': tripId,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Traveller',
        'senderAvatar': user.photoURL,
        'content': sanitized,
        'clientId': effectiveClientId,
        'kind': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(payload);

      return ChatMessage(
        id: docRef.id,
        tripId: tripId,
        senderId: user.uid,
        content: sanitized,
        createdAt: now,
        senderName: user.displayName,
        senderAvatar: user.photoURL,
        status: MessageSendStatus.sent,
        clientId: effectiveClientId,
        clientTempId: effectiveClientId,
      );
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  @override
  Future<void> sendTyping(String tripId, String userName) async {
    final user = _auth.currentUser;
    if (user == null || DemoData.enabled) return;

    try {
      await _firestore
          .collection('chats')
          .doc(tripId)
          .collection('typing')
          .doc(user.uid)
          .set({
        'userName': ChatMessage.formatDisplayName(userName),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Ephemeral typing indicators fail silently
    }
  }

  @override
  RealtimeChannel subscribeToTripMessages(
    String tripId, {
    required void Function(ChatMessage message) onMessage,
    void Function(String messageId)? onMessageDeleted,
  }) {
    final stream = _firestore
        .collection('chats')
        .doc(tripId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();

    final subscription = stream.listen((snapshot) {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = Map<String, dynamic>.from(change.doc.data() ?? {});
          data['id'] = change.doc.id;
          onMessage(ChatMessage.fromJson(data));
        } else if (change.type == DocumentChangeType.removed) {
          onMessageDeleted?.call(change.doc.id);
        }
      }
    });

    return FirestoreRealtimeChannel(subscription);
  }

  @override
  RealtimeChannel subscribeToTyping(
    String tripId, {
    required void Function(String userName) onUserTyping,
  }) {
    final stream = _firestore
        .collection('chats')
        .doc(tripId)
        .collection('typing')
        .snapshots();

    final currentUid = _auth.currentUser?.uid;

    final subscription = stream.listen((snapshot) {
      for (final doc in snapshot.docs) {
        if (doc.id == currentUid) continue;
        final data = doc.data();
        final userName = data['userName'] as String?;
        if (userName != null && userName.isNotEmpty) {
          onUserTyping(userName);
        }
      }
    });

    return FirestoreRealtimeChannel(subscription);
  }

  @override
  Future<void> blockUser(String userId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to block a user.');
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocks')
          .doc(userId)
          .set({
        'blockedId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Unable to block user: ${e.toString()}');
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to unblock a user.');
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocks')
          .doc(userId)
          .delete();
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
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to report a user.');
    }

    final cleanReason = TextSanitizer.limit(reason, 100);
    final cleanDetails = TextSanitizer.limit(details, 2000);

    try {
      await _firestore.collection('reports').add({
        'reportedUserId': userId,
        'reporterUserId': user.uid,
        'reason': cleanReason,
        'details': cleanDetails,
        'tripId': tripId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Unable to submit report: ${e.toString()}');
    }
  }

  @override
  Future<Set<String>> getBlockedUserIds() async {
    final user = _auth.currentUser;
    if (user == null) return const {};

    try {
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('blocks')
          .get();

      return snap.docs.map((doc) => doc.id).toSet();
    } catch (_) {
      return const {};
    }
  }
}

/// Fallback / Legacy Supabase Chat Repository
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
      final summaryResponse =
          await _client.rpc<dynamic>('chat_list_summary');
      final summaryList = summaryResponse as List<dynamic>?;
      if (summaryList != null && summaryList.isNotEmpty) {
        return summaryList
            .map((item) => TripChatGroup.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

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
    if (_client == null || DemoData.enabled) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.rpc<dynamic>('mark_chat_read', params: {'p_trip_id': tripId});
    } catch (_) {}
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
    } catch (_) {
      throw Exception('Failed to send message. Please retry.');
    }
  }

  @override
  Future<void> sendTyping(String tripId, String userName) async {}

  @override
  RealtimeChannel subscribeToTyping(
    String tripId, {
    required void Function(String userName) onUserTyping,
  }) {
    if (_client == null) {
      return FirestoreRealtimeChannel(null);
    }
    return _client.channel('typing:$tripId');
  }

  @override
  Future<void> blockUser(String userId) async {}

  @override
  Future<void> unblockUser(String userId) async {}

  @override
  Future<void> reportUser(
    String userId, {
    required String reason,
    required String details,
    String? tripId,
  }) async {}

  @override
  Future<Set<String>> getBlockedUserIds() async => const {};

  @override
  RealtimeChannel subscribeToTripMessages(
    String tripId, {
    required void Function(ChatMessage message) onMessage,
    void Function(String messageId)? onMessageDeleted,
  }) {
    if (_client == null) {
      return FirestoreRealtimeChannel(null);
    }
    return _client.channel('public:messages:trip_id=$tripId');
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  if (firestore != null && auth != null) {
    return FirestoreChatRepository(firestore, auth);
  }
  final client = ref.watch(supabaseClientProvider);
  return SupabaseChatRepository(client);
});

final unlockedChatsProvider = FutureProvider<List<TripChatGroup>>((ref) {
  return ref.watch(chatRepositoryProvider).getUnlockedChats();
});

final blockedUsersProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(chatRepositoryProvider).getBlockedUserIds();
});
