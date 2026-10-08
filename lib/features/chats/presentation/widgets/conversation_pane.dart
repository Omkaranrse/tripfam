import 'package:flutter/material.dart';

import 'chat_room_view.dart';

/// Backward-compatible wrapper delegating to [ChatRoomView].
class ConversationPane extends StatelessWidget {
  const ConversationPane({
    required this.tripId,
    this.tripTitle,
    this.destination,
    this.onBackPressed,
    this.isReadOnly = false,
    super.key,
  });

  final String tripId;
  final String? tripTitle;
  final String? destination;
  final VoidCallback? onBackPressed;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    return ChatRoomView(
      tripId: tripId,
      tripTitle: tripTitle,
      destination: destination,
      onBackPressed: onBackPressed,
      isReadOnly: isReadOnly,
    );
  }
}
