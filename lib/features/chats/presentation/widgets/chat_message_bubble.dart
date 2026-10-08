import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/chat_grouped_item.dart';
import '../../domain/chat_message.dart';
import 'chat_moderation_dialogs.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.item,
    this.onRetry,
    super.key,
  });

  final ChatMessageBubbleItem item;
  final VoidCallback? onRetry;

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showActionSheet(BuildContext context) {
    final senderName = item.message.formattedSenderName;
    final content = item.message.content;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(35),
                      child: Text(
                        senderName.isNotEmpty ? senderName[0] : 'U',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.copy_rounded, size: 20),
                title: const Text('Copy message'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  Navigator.pop(bottomSheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              if (!item.isMine) ...[
                ListTile(
                  leading: const Icon(Icons.flag_outlined,
                      color: Colors.orange, size: 20),
                  title: const Text('Report message or user'),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    ChatReportDialog.show(
                      context,
                      reportedUserId: item.message.senderId,
                      reportedUserName: senderName,
                      tripId: item.message.tripId,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined,
                      color: Colors.red, size: 20),
                  title: const Text('Block user'),
                  subtitle: const Text(
                    'Their messages will be permanently hidden',
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    ChatBlockConfirmDialog.show(
                      context,
                      userId: item.message.senderId,
                      userName: senderName,
                    );
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLinkTap(BuildContext context, String urlString) async {
    Uri? uri;
    try {
      uri = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    } catch (_) {
      return;
    }

    final domain = uri.host.isNotEmpty ? uri.host : urlString;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open External Link'),
        content: Text(
          'You are navigating to external domain:\n\n$domain\n\nDo you want to open this page in your browser?',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open Link'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to open link in external browser')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final message = item.message;
    final timeStr = _formatTime(message.createdAt);
    final senderLabel = item.isMine ? 'You' : message.formattedSenderName;
    final semanticLabel = '$senderLabel, $timeStr, ${message.content}';

    // Solid surfaces (no glass)
    final ownBg = isDark
        ? const Color(0xFF26402E) // Deep sage dark
        : const Color(0xFFD6E8DC); // Fresh sage light
    final ownTextColor = isDark ? Colors.white : const Color(0xFF132219);

    final otherBg = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : const Color(0xFFF1F4F2); // Subtle neutral
    final otherTextColor = theme.colorScheme.onSurface;

    final bubbleBg = item.isMine ? ownBg : otherBg;
    final textColor = item.isMine ? ownTextColor : otherTextColor;

    // 18px radius with 4px tight corner on grouped side
    final borderRadius = item.isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          );

    return RepaintBoundary(
      child: Semantics(
        label: semanticLabel,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: item.gapBelow,
          ),
          child: Column(
            crossAxisAlignment: item.isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Sender header for other users on first message in group
              if (item.showSenderHeader) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4, top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary.withAlpha(35),
                        backgroundImage: message.senderAvatar != null
                            ? NetworkImage(message.senderAvatar!)
                            : null,
                        child: message.senderAvatar == null
                            ? Text(
                                senderLabel.isNotEmpty ? senderLabel[0] : 'U',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        senderLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Bubble & Status Row
              Row(
                mainAxisAlignment: item.isMine
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Retry button for failed messages
                  if (item.isMine && message.status == MessageSendStatus.failed) ...[
                    IconButton(
                      icon: Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 22,
                      ),
                      tooltip: 'Failed to send. Tap to retry.',
                      onPressed: onRetry,
                    ),
                  ],

                  // The Bubble
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 520, // Max 520px on wide screens
                    ),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleBg,
                        borderRadius: borderRadius,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: borderRadius,
                          onLongPress: () => _showActionSheet(context),
                          onSecondaryTap: () => _showActionSheet(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: _buildBubbleContent(
                              context,
                              message.content,
                              timeStr,
                              textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context,
    String content,
    String timeStr,
    Color textColor,
  ) {
    final theme = Theme.of(context);
    final urlRegex = RegExp(
      r'((https?:\/\/)|(www\.))[^\s]+',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    int start = 0;

    for (final match in urlRegex.allMatches(content)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: content.substring(start, match.start),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: textColor,
            ),
          ),
        );
      }

      final url = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _handleLinkTap(context, url),
            child: Text(
              url,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      );
      start = match.end;
    }

    if (start < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(start),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: textColor,
          ),
        ),
      );
    }

    // Inline Timestamp & Status icon at bottom right of bubble
    final statusIcon = _buildStatusIcon(context);

    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text.rich(
          TextSpan(children: spans),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: textColor.withAlpha(150),
              ),
            ),
            if (statusIcon != null) ...[
              const SizedBox(width: 4),
              statusIcon,
            ],
          ],
        ),
      ],
    );
  }

  Widget? _buildStatusIcon(BuildContext context) {
    if (!item.isMine) return null;
    final theme = Theme.of(context);

    switch (item.message.status) {
      case MessageSendStatus.sending:
        return SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.primary,
          ),
        );
      case MessageSendStatus.sent:
        return Icon(
          Icons.done_rounded,
          size: 13,
          color: theme.colorScheme.primary,
        );
      case MessageSendStatus.failed:
        return Icon(
          Icons.error_outline_rounded,
          size: 13,
          color: theme.colorScheme.error,
        );
    }
  }
}
