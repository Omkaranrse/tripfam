import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../account/data/auth_repository.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';
import 'chat_message_bubble.dart';

class ConversationPane extends ConsumerStatefulWidget {
  const ConversationPane({
    required this.tripId,
    this.tripTitle,
    this.destination,
    this.onBackPressed,
    super.key,
  });

  final String tripId;
  final String? tripTitle;
  final String? destination;
  final VoidCallback? onBackPressed;

  @override
  ConsumerState<ConversationPane> createState() => _ConversationPaneState();
}

class _ConversationPaneState extends ConsumerState<ConversationPane> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoadingInitial = true;
  bool _isLoadingEarlier = false;
  bool _hasMoreEarlier = true;
  String? _errorMessage;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _initRealtimeSubscription();
  }

  @override
  void didUpdateWidget(covariant ConversationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) {
      _realtimeChannel?.unsubscribe();
      _messages.clear();
      _hasMoreEarlier = true;
      _isLoadingInitial = true;
      _loadInitialMessages();
      _initRealtimeSubscription();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initRealtimeSubscription() {
    try {
      final repo = ref.read(chatRepositoryProvider);
      _realtimeChannel = repo.subscribeToTripMessages(
        widget.tripId,
        onMessage: (newMessage) {
          if (!mounted) return;
          setState(() {
            // Check if this incoming message matches an optimistic message
            final existingIndex = _messages.indexWhere(
              (m) =>
                  m.id == newMessage.id ||
                  (m.clientTempId != null &&
                      m.clientTempId == newMessage.clientTempId) ||
                  (m.status == MessageSendStatus.sending &&
                      m.senderId == newMessage.senderId &&
                      m.content == newMessage.content),
            );

            if (existingIndex != -1) {
              _messages[existingIndex] = newMessage;
            } else {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
        },
        onMessageDeleted: (deletedId) {
          if (!mounted) return;
          setState(() {
            _messages.removeWhere((m) => m.id == deletedId);
          });
        },
      );
    } catch (_) {
      // Subscriptions fail gracefully if realtime not configured
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = null;
    });

    try {
      final messages = await ref
          .read(chatRepositoryProvider)
          .getMessages(widget.tripId, limit: 30);

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(messages);
          _isLoadingInitial = false;
          _hasMoreEarlier = messages.length >= 30;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadEarlierMessages() async {
    if (_isLoadingEarlier || !_hasMoreEarlier || _messages.isEmpty) return;

    setState(() => _isLoadingEarlier = true);

    try {
      final oldestMessage = _messages.first;
      final earlier = await ref
          .read(chatRepositoryProvider)
          .getMessages(
            widget.tripId,
            before: oldestMessage.createdAt,
            limit: 30,
          );

      if (mounted) {
        setState(() {
          if (earlier.isEmpty) {
            _hasMoreEarlier = false;
          } else {
            _messages.insertAll(0, earlier);
            _hasMoreEarlier = earlier.length >= 30;
          }
          _isLoadingEarlier = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEarlier = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final rawText = _messageController.text;
    String cleanText;

    try {
      cleanText = ChatMessage.validateAndSanitize(rawText);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ArgumentError: ', '')),
        ),
      );
      return;
    }

    _messageController.clear();

    final currentUser = ref.read(authRepositoryProvider).currentUser;
    final currentUserId = currentUser?.id ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    final optimisticMsg = ChatMessage(
      id: tempId,
      tripId: widget.tripId,
      senderId: currentUserId,
      content: cleanText,
      createdAt: DateTime.now(),
      status: MessageSendStatus.sending,
      clientTempId: tempId,
    );

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    try {
      final confirmedMsg = await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.tripId, cleanText, tempId: tempId);

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.clientTempId == tempId);
          if (index != -1) {
            _messages[index] = confirmedMsg;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.clientTempId == tempId);
          if (index != -1) {
            _messages[index] = optimisticMsg.copyWith(
              status: MessageSendStatus.failed,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _retrySend(tempId, cleanText),
            ),
          ),
        );
      }
    }
  }

  Future<void> _retrySend(String tempId, String text) async {
    setState(() {
      final index = _messages.indexWhere((m) => m.clientTempId == tempId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          status: MessageSendStatus.sending,
        );
      }
    });

    try {
      final confirmed = await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.tripId, text, tempId: tempId);

      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.clientTempId == tempId);
          if (index != -1) {
            _messages[index] = confirmed;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.clientTempId == tempId);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              status: MessageSendStatus.failed,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(authRepositoryProvider).currentUser?.id;
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final blockedUsers = blockedUsersAsync.value ?? const <String>{};

    // Filter out messages from blocked users
    final visibleMessages = _messages
        .where((m) => !blockedUsers.contains(m.senderId))
        .toList();

    return Column(
      children: [
        // Conversation Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              if (widget.onBackPressed != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.onBackPressed,
                ),
                const SizedBox(width: 4),
              ],
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.groups_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tripTitle ?? 'Trip Group Chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.destination != null)
                      Text(
                        widget.destination!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sync_rounded),
                tooltip: 'Reconnect / Refresh',
                onPressed: () {
                  _loadInitialMessages();
                  ref.invalidate(blockedUsersProvider);
                },
              ),
            ],
          ),
        ),

        // Message Feed
        Expanded(
          child: _isLoadingInitial
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_clock_outlined,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInitialMessages,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : visibleMessages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chat Unlocked!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Say hi to your travel group and start planning your itinerary.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(160),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: visibleMessages.length + (_hasMoreEarlier ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_hasMoreEarlier && index == 0) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: _isLoadingEarlier
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : TextButton.icon(
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Load earlier messages'),
                                  onPressed: _loadEarlierMessages,
                                ),
                        ),
                      );
                    }

                    final msgIndex = _hasMoreEarlier ? index - 1 : index;
                    final msg = visibleMessages[msgIndex];

                    return ChatMessageBubble(
                      message: msg,
                      isMine: msg.isMine(currentUserId),
                      onRetry:
                          msg.status == MessageSendStatus.failed &&
                              msg.clientTempId != null
                          ? () => _retrySend(msg.clientTempId!, msg.content)
                          : null,
                    );
                  },
                ),
        ),

        // Message Input Field
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLines: 4,
                    minLines: 1,
                    maxLength: 4000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      counterText: '', // Hide default counter to keep bar clean
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
