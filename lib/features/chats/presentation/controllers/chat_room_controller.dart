import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/chat_repository.dart';
import '../../domain/chat_grouped_item.dart';
import '../../domain/chat_message.dart';
import '../../../account/data/auth_repository.dart';
import 'chat_list_controller.dart';

class ChatRoomState {
  const ChatRoomState({
    required this.tripId,
    this.messages = const [],
    this.displayItems = const [],
    this.typingUsers = const {},
    this.isLoadingInitial = true,
    this.isLoadingEarlier = false,
    this.hasMoreEarlier = true,
    this.errorMessage,
    this.unreadCountOnOpen = 0,
    this.isReconnecting = false,
    this.isPinnedCardCollapsed = true,
    this.newMessagesCountWhileScrolledUp = 0,
  });

  final String tripId;
  final List<ChatMessage> messages;
  final List<ChatListItem> displayItems;
  final Set<String> typingUsers;
  final bool isLoadingInitial;
  final bool isLoadingEarlier;
  final bool hasMoreEarlier;
  final String? errorMessage;
  final int unreadCountOnOpen;
  final bool isReconnecting;
  final bool isPinnedCardCollapsed;
  final int newMessagesCountWhileScrolledUp;

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    List<ChatListItem>? displayItems,
    Set<String>? typingUsers,
    bool? isLoadingInitial,
    bool? isLoadingEarlier,
    bool? hasMoreEarlier,
    String? errorMessage,
    int? unreadCountOnOpen,
    bool? isReconnecting,
    bool? isPinnedCardCollapsed,
    int? newMessagesCountWhileScrolledUp,
  }) {
    return ChatRoomState(
      tripId: tripId,
      messages: messages ?? this.messages,
      displayItems: displayItems ?? this.displayItems,
      typingUsers: typingUsers ?? this.typingUsers,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingEarlier: isLoadingEarlier ?? this.isLoadingEarlier,
      hasMoreEarlier: hasMoreEarlier ?? this.hasMoreEarlier,
      errorMessage: errorMessage,
      unreadCountOnOpen: unreadCountOnOpen ?? this.unreadCountOnOpen,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      isPinnedCardCollapsed:
          isPinnedCardCollapsed ?? this.isPinnedCardCollapsed,
      newMessagesCountWhileScrolledUp:
          newMessagesCountWhileScrolledUp ?? this.newMessagesCountWhileScrolledUp,
    );
  }
}

class ChatRoomNotifier extends StateNotifier<ChatRoomState> {
  ChatRoomNotifier({
    required this.tripId,
    required this.repository,
    required this.currentUserId,
    required this.currentUserName,
    required this.ref,
    int initialUnreadCount = 0,
  }) : super(ChatRoomState(
          tripId: tripId,
          unreadCountOnOpen: initialUnreadCount,
        )) {
    loadInitial();
  }

  final String tripId;
  final ChatRepository repository;
  final String? currentUserId;
  final String? currentUserName;
  final Ref ref;

  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _typingSubscription;
  final Map<String, Timer> _typingTimers = {};
  DateTime? _lastTypingBroadcast;

  /// Client-side send rate limiting timestamps
  final List<DateTime> _recentSendTimestamps = [];

  @override
  void dispose() {
    _messagesSubscription?.unsubscribe();
    _typingSubscription?.unsubscribe();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, errorMessage: null);

    try {
      final initial = await repository.getMessages(tripId, limit: 40);
      if (!mounted) return;

      final display = ChatGroupingEngine.buildDisplayItems(
        messages: initial,
        unreadCountOnOpen: state.unreadCountOnOpen,
        currentUserId: currentUserId,
      );

      state = state.copyWith(
        messages: initial,
        displayItems: display,
        isLoadingInitial: false,
        hasMoreEarlier: initial.length >= 40,
        errorMessage: null,
      );

      // Mark trip read on server and update list controller
      unawaited(repository.markChatRead(tripId));
      ref.read(chatListControllerProvider.notifier).markTripRead(tripId);

      _setupRealtime();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingInitial: false,
        errorMessage: 'Unable to load conversation. Please check your connection.',
      );
    }
  }

  void _setupRealtime() {
    try {
      _messagesSubscription = repository.subscribeToTripMessages(
        tripId,
        onMessage: (newMsg) {
          _onIncomingMessage(newMsg);
        },
        onMessageDeleted: (deletedId) {
          final updated =
              state.messages.where((m) => m.id != deletedId).toList();
          _recomputeDisplay(updated);
        },
      );

      _typingSubscription = repository.subscribeToTyping(
        tripId,
        onUserTyping: (userName) {
          _onUserTyping(userName);
        },
      );
    } catch (_) {
      // Offline or mock mode
    }
  }

  void _onIncomingMessage(ChatMessage newMsg) {
    // If incoming message matches an optimistic client_id, resolve it
    final existingIndex = state.messages.indexWhere(
      (m) =>
          m.id == newMsg.id ||
          (m.clientId != null && m.clientId == newMsg.clientId) ||
          (m.status == MessageSendStatus.sending &&
              m.senderId == newMsg.senderId &&
              m.content == newMsg.content),
    );

    final list = List<ChatMessage>.from(state.messages);
    if (existingIndex != -1) {
      list[existingIndex] = newMsg;
    } else {
      list.add(newMsg);
    }

    _recomputeDisplay(list);

    // Update list preview
    ref.read(chatListControllerProvider.notifier).updateLastMessage(
          tripId: tripId,
          messageContent: newMsg.content,
          createdAt: newMsg.createdAt,
          senderName: newMsg.formattedSenderName,
          isMine: newMsg.isMine(currentUserId),
        );
  }

  void _onUserTyping(String rawName) {
    final formatted = ChatMessage.formatDisplayName(rawName);
    // Ignore own typing notifications
    if (currentUserName != null &&
        ChatMessage.formatDisplayName(currentUserName) == formatted) {
      return;
    }

    final currentTyping = Set<String>.from(state.typingUsers)..add(formatted);
    state = state.copyWith(typingUsers: currentTyping);

    // Ephemeral: clear after 3 seconds
    _typingTimers[formatted]?.cancel();
    _typingTimers[formatted] = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      final updated = Set<String>.from(state.typingUsers)..remove(formatted);
      state = state.copyWith(typingUsers: updated);
    });
  }

  Future<void> loadEarlier() async {
    if (state.isLoadingEarlier || !state.hasMoreEarlier || state.messages.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingEarlier: true);
    final oldest = state.messages.first;

    try {
      final earlier = await repository.getMessages(
        tripId,
        before: oldest.createdAt,
        limit: 30,
      );
      if (!mounted) return;

      final combined = [...earlier, ...state.messages];
      _recomputeDisplay(combined, hasMore: earlier.length >= 30);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingEarlier: false);
    }
  }

  Future<void> send(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    // Client-side rate limit: max 5 sends within 5 seconds
    final now = DateTime.now();
    _recentSendTimestamps.removeWhere(
        (t) => now.difference(t) > const Duration(seconds: 5));
    if (_recentSendTimestamps.length >= 5) {
      throw StateError('Please slow down. You are sending messages too fast.');
    }
    _recentSendTimestamps.add(now);

    final sanitized =
        ChatMessage.validateAndSanitize(trimmed, maxLength: 2000);
    final clientId = generateClientUuid();

    final optimistic = ChatMessage(
      id: clientId,
      clientId: clientId,
      clientTempId: clientId,
      tripId: tripId,
      senderId: currentUserId ?? 'current_user',
      senderName: currentUserName ?? 'You',
      content: sanitized,
      createdAt: now,
      status: MessageSendStatus.sending,
      kind: MessageKind.user,
    );

    final updated = List<ChatMessage>.from(state.messages)..add(optimistic);
    _recomputeDisplay(updated);

    try {
      final serverMsg = await repository.sendMessage(
        tripId,
        sanitized,
        clientId: clientId,
      );
      if (!mounted) return;

      final resolvedList = state.messages.map((m) {
        if (m.clientId == clientId || m.id == clientId) {
          return serverMsg.copyWith(status: MessageSendStatus.sent);
        }
        return m;
      }).toList();

      _recomputeDisplay(resolvedList);

      ref.read(chatListControllerProvider.notifier).updateLastMessage(
            tripId: tripId,
            messageContent: serverMsg.content,
            createdAt: serverMsg.createdAt,
            senderName: serverMsg.formattedSenderName,
            isMine: true,
          );
    } catch (e) {
      if (!mounted) return;
      // Mark as failed for retry
      final failedList = state.messages.map((m) {
        if (m.clientId == clientId || m.id == clientId) {
          return m.copyWith(status: MessageSendStatus.failed);
        }
        return m;
      }).toList();

      _recomputeDisplay(failedList);
    }
  }

  Future<void> retry(String clientId) async {
    final index = state.messages.indexWhere(
        (m) => m.clientId == clientId || m.id == clientId);
    if (index == -1) return;

    final target = state.messages[index];
    final retryingMsg = target.copyWith(status: MessageSendStatus.sending);

    final list = List<ChatMessage>.from(state.messages);
    list[index] = retryingMsg;
    _recomputeDisplay(list);

    try {
      final serverMsg = await repository.sendMessage(
        tripId,
        target.content,
        clientId: target.clientId ?? clientId,
      );
      if (!mounted) return;

      final resolvedList = state.messages.map((m) {
        if (m.clientId == clientId || m.id == clientId) {
          return serverMsg.copyWith(status: MessageSendStatus.sent);
        }
        return m;
      }).toList();

      _recomputeDisplay(resolvedList);
    } catch (_) {
      if (!mounted) return;
      final failedList = state.messages.map((m) {
        if (m.clientId == clientId || m.id == clientId) {
          return m.copyWith(status: MessageSendStatus.failed);
        }
        return m;
      }).toList();

      _recomputeDisplay(failedList);
    }
  }

  void broadcastTyping() {
    final now = DateTime.now();
    if (_lastTypingBroadcast != null &&
        now.difference(_lastTypingBroadcast!) < const Duration(seconds: 2)) {
      return; // Throttled to once per 2 seconds
    }
    _lastTypingBroadcast = now;
    if (currentUserName != null) {
      repository.sendTyping(tripId, currentUserName!);
    }
  }

  void togglePinnedCard() {
    state = state.copyWith(
        isPinnedCardCollapsed: !state.isPinnedCardCollapsed);
  }

  void notifyScrolledUpNewMessage() {
    state = state.copyWith(
      newMessagesCountWhileScrolledUp:
          state.newMessagesCountWhileScrolledUp + 1,
    );
  }

  void resetScrolledUpNewMessages() {
    state = state.copyWith(newMessagesCountWhileScrolledUp: 0);
  }

  void setConnectionStatus(bool isReconnecting) {
    state = state.copyWith(isReconnecting: isReconnecting);
  }

  void _recomputeDisplay(List<ChatMessage> messages, {bool? hasMore}) {
    final display = ChatGroupingEngine.buildDisplayItems(
      messages: messages,
      unreadCountOnOpen: state.unreadCountOnOpen,
      currentUserId: currentUserId,
    );

    state = state.copyWith(
      messages: messages,
      displayItems: display,
      isLoadingEarlier: false,
      hasMoreEarlier: hasMore ?? state.hasMoreEarlier,
    );
  }
}

final chatRoomControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatRoomNotifier, ChatRoomState, String>((ref, tripId) {
  final repo = ref.watch(chatRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final listState = ref.read(chatListControllerProvider);

  final matchingGroup = listState.chats.cast<TripChatGroup?>().firstWhere(
        (c) => c?.tripId == tripId,
        orElse: () => null,
      );

  final unreadCount = matchingGroup?.unreadCount ?? 0;

  return ChatRoomNotifier(
    tripId: tripId,
    repository: repo,
    currentUserId: user?.id,
    currentUserName: user?.userMetadata?['display_name'] as String? ?? 'You',
    ref: ref,
    initialUnreadCount: unreadCount,
  );
});
