import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../trips/data/trip_repository.dart';
import 'widgets/chat_room_view.dart';

class ChatConversationScreen extends ConsumerWidget {
  const ChatConversationScreen({
    required this.tripId,
    this.tripTitle,
    this.destination,
    super.key,
  });

  final String tripId;
  final String? tripTitle;
  final String? destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripAsync = ref.watch(tripDetailProvider(tripId));
    final title = tripTitle ??
        (tripAsync.value != null
            ? 'Trip to ${tripAsync.value!.destination}'
            : 'Trip Group Chat');
    final dest = destination ?? tripAsync.value?.destination;
    final isPast = tripAsync.value?.isPast ?? false;

    return ChatRoomView(
      tripId: tripId,
      tripTitle: title,
      destination: dest,
      isReadOnly: isPast,
      onBackPressed: () => context.pop(),
    );
  }
}
