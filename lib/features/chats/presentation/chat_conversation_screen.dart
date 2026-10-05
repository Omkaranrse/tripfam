import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../trips/data/trip_repository.dart';
import 'widgets/conversation_pane.dart';

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
    final title =
        tripTitle ??
        (tripAsync.value != null
            ? 'Trip to ${tripAsync.value!.destination}'
            : 'Trip Group Chat');
    final dest = destination ?? tripAsync.value?.destination;

    return Scaffold(
      body: SafeArea(
        child: ConversationPane(
          tripId: tripId,
          tripTitle: title,
          destination: dest,
          onBackPressed: () => context.pop(),
        ),
      ),
    );
  }
}
