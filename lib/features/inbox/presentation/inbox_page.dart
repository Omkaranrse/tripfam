import 'package:flutter/material.dart';

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      children: [
        Text('Inbox', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Conversations with fellow travellers will appear here.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        const _EmptyInboxPanel(),
      ],
    );
  }
}

class _EmptyInboxPanel extends StatelessWidget {
  const _EmptyInboxPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.chat_bubble_outline, color: theme.colorScheme.secondary),
            const SizedBox(height: 16),
            Text('No conversations yet', style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
