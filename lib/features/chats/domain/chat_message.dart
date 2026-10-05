import '../../../core/utils/text_sanitizer.dart';

enum MessageSendStatus { sent, sending, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.status = MessageSendStatus.sent,
    this.clientTempId,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderProfile = json['sender_profile'] as Map<String, dynamic>?;

    return ChatMessage(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      senderId: json['sender_id'] as String,
      content: TextSanitizer.sanitize(json['content'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderName: senderProfile != null
          ? TextSanitizer.sanitize(senderProfile['display_name'] as String?)
          : null,
      senderAvatar: senderProfile?['avatar_path'] as String?,
      status: MessageSendStatus.sent,
    );
  }

  final String id;
  final String tripId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  final MessageSendStatus status;
  final String? clientTempId;

  bool isMine(String? currentUserId) =>
      currentUserId != null && senderId == currentUserId;

  ChatMessage copyWith({
    String? id,
    MessageSendStatus? status,
    String? content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      tripId: tripId,
      senderId: senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName,
      senderAvatar: senderAvatar,
      status: status ?? this.status,
      clientTempId: clientTempId,
    );
  }

  /// Security: Sanitizes and limits the message to prevent HTML/XSS injection.
  /// Throws [ArgumentError] if the message is empty or exceeds the 4000 character limit.
  static String validateAndSanitize(String raw) {
    final clean = TextSanitizer.sanitize(raw);
    if (clean.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    if (clean.length > 4000) {
      throw ArgumentError(
        'Message exceeds maximum allowed length of 4000 characters.',
      );
    }
    return clean;
  }
}

class TripChatGroup {
  const TripChatGroup({
    required this.tripId,
    required this.tripTitle,
    required this.destination,
    required this.hostId,
    this.hostName,
    this.memberCount = 1,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory TripChatGroup.fromJson(Map<String, dynamic> json) {
    return TripChatGroup(
      tripId: json['trip_id'] as String,
      tripTitle: TextSanitizer.sanitize(json['trip_title'] as String?),
      destination: TextSanitizer.sanitize(json['destination'] as String?),
      hostId: json['host_id'] as String,
      hostName: json['host_name'] != null
          ? TextSanitizer.sanitize(json['host_name'] as String?)
          : null,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      lastMessage: json['last_message'] != null
          ? TextSanitizer.sanitize(json['last_message'] as String?)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
    );
  }

  final String tripId;
  final String tripTitle;
  final String destination;
  final String hostId;
  final String? hostName;
  final int memberCount;
  final String? lastMessage;
  final DateTime? lastMessageAt;
}
