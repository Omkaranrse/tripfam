import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';

class ChatListState {
  const ChatListState({
    this.chats = const [],
    this.isLoading = true,
    this.errorMessage,
    this.searchQuery = '',
  });

  final List<TripChatGroup> chats;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;

  /// Filtered by search query (title or destination)
  List<TripChatGroup> get filteredChats {
    if (searchQuery.trim().isEmpty) return chats;
    final q = searchQuery.toLowerCase().trim();
    return chats.where((c) {
      return c.tripTitle.toLowerCase().contains(q) ||
          c.destination.toLowerCase().contains(q);
    }).toList();
  }

  /// Active upcoming trips
  List<TripChatGroup> get upcomingChats {
    return filteredChats.where((c) => !c.isPast).toList();
  }

  /// Past read-only trips
  List<TripChatGroup> get pastChats {
    return filteredChats.where((c) => c.isPast).toList();
  }

  ChatListState copyWith({
    List<TripChatGroup>? chats,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return ChatListState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ChatListNotifier extends StateNotifier<ChatListState> {
  ChatListNotifier(this._repository) : super(const ChatListState()) {
    loadChats();
  }

  final ChatRepository _repository;

  Future<void> loadChats() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final chats = await _repository.getUnlockedChats();
      state = state.copyWith(
        chats: chats,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load active conversations. Please check your network.',
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void markTripRead(String tripId) {
    final updated = state.chats.map((c) {
      if (c.tripId == tripId) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();
    state = state.copyWith(chats: updated);
    _repository.markChatRead(tripId);
  }

  void updateLastMessage({
    required String tripId,
    required String messageContent,
    required DateTime createdAt,
    required String senderName,
    required bool isMine,
  }) {
    final index = state.chats.indexWhere((c) => c.tripId == tripId);
    if (index != -1) {
      final existing = state.chats[index];
      final newUnread = isMine ? existing.unreadCount : existing.unreadCount + 1;
      final updatedGroup = existing.copyWith(
        lastMessage: messageContent,
        lastMessageAt: createdAt,
        lastSenderName: senderName,
        unreadCount: newUnread,
      );
      final list = List<TripChatGroup>.from(state.chats);
      list.removeAt(index);
      list.insert(0, updatedGroup);
      state = state.copyWith(chats: list);
    }
  }
}

final chatListControllerProvider =
    StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatListNotifier(repo);
});
