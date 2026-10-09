import '../../../core/utils/text_sanitizer.dart';

enum MessageSendStatus { sent, sending, failed }

enum MessageKind {
  user,
  system;

  static MessageKind fromString(String? val) {
    if (val == 'system') return MessageKind.system;
    return MessageKind.user;
  }
}

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
    this.clientId,
    this.kind = MessageKind.user,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final senderProfile = json['sender_profile'] as Map<String, dynamic>?;

    DateTime parsedDate;
    final rawDate = json['created_at'] ?? json['createdAt'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate != null && rawDate.runtimeType.toString().contains('Timestamp')) {
      try {
        parsedDate = (rawDate as dynamic).toDate() as DateTime;
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return ChatMessage(
      id: (json['id'] as String?) ?? '',
      tripId: (json['trip_id'] as String?) ?? (json['tripId'] as String?) ?? '',
      senderId: (json['sender_id'] as String?) ?? (json['senderId'] as String?) ?? '',
      content: TextSanitizer.sanitize(json['content'] as String?),
      createdAt: parsedDate,
      senderName: senderProfile != null
          ? TextSanitizer.sanitize(senderProfile['display_name'] as String?)
          : TextSanitizer.sanitize(json['senderName'] as String?),
      senderAvatar: senderProfile?['avatar_path'] as String? ?? (json['senderAvatar'] as String?),
      status: MessageSendStatus.sent,
      clientId: (json['client_id'] as String?) ?? (json['clientId'] as String?),
      clientTempId: (json['client_id'] as String?) ?? (json['clientId'] as String?),
      kind: MessageKind.fromString(json['kind'] as String?),
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
  final String? clientId;
  final MessageKind kind;

  bool isMine(String? currentUserId) =>
      currentUserId != null && senderId == currentUserId;

  bool get isSystem => kind == MessageKind.system;

  /// Display names only: "First Name + Last Initial" (e.g. "Aarav P."), never email/phone
  String get formattedSenderName => formatDisplayName(senderName);

  static String formatDisplayName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Fellow Traveller';
    var clean = raw.trim();
    // If it looks like an email, strip domain
    if (clean.contains('@')) {
      clean = clean.split('@').first;
    }
    // Remove any phone characters if purely digits
    if (RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(clean)) {
      return 'Traveller';
    }
    final parts =
        clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Fellow Traveller';
    if (parts.length == 1) return parts[0];
    final firstName = parts[0];
    final lastInitial = parts[1][0].toUpperCase();
    return '$firstName $lastInitial.';
  }

  ChatMessage copyWith({
    String? id,
    MessageSendStatus? status,
    String? content,
    DateTime? createdAt,
    String? senderName,
    String? senderAvatar,
    String? clientTempId,
    String? clientId,
    MessageKind? kind,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      tripId: tripId,
      senderId: senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      status: status ?? this.status,
      clientTempId: clientTempId ?? this.clientTempId,
      clientId: clientId ?? this.clientId,
      kind: kind ?? this.kind,
    );
  }

  /// Security: Sanitizes and limits the message to plain text (defaults to 4000, composer enforces 2000).
  /// Never allows HTML. Throws [ArgumentError] if empty or exceeds limit.
  static String validateAndSanitize(String raw, {int maxLength = 4000}) {
    final clean = TextSanitizer.sanitize(raw).trim();
    if (clean.isEmpty) {
      throw ArgumentError('Message cannot be empty.');
    }
    if (clean.length > maxLength) {
      throw ArgumentError(
        'Message exceeds maximum allowed length of $maxLength characters.',
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
    this.startDate,
    this.endDate,
    this.isPast = false,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastSenderName,
    this.unreadCount = 0,
    this.coverImageUrl,
  });

  factory TripChatGroup.fromJson(Map<String, dynamic> json) {
    final startDateStr = json['start_date'] as String?;
    final endDateStr = json['end_date'] as String?;
    final isPastVal = json['is_past'] as bool?;

    DateTime? startDate;
    if (startDateStr != null) {
      startDate = DateTime.tryParse(startDateStr);
    }
    DateTime? endDate;
    if (endDateStr != null) {
      endDate = DateTime.tryParse(endDateStr);
    }

    final computedIsPast = isPastVal ??
        (endDate != null && endDate.isBefore(DateTime.now()));

    return TripChatGroup(
      tripId: json['trip_id'] as String,
      tripTitle: TextSanitizer.sanitize(json['trip_title'] as String?),
      destination: TextSanitizer.sanitize(json['destination'] as String?),
      hostId: json['host_id'] as String,
      hostName: json['host_name'] != null
          ? TextSanitizer.sanitize(json['host_name'] as String?)
          : null,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 1,
      startDate: startDate,
      endDate: endDate,
      isPast: computedIsPast,
      lastMessage: json['last_message'] != null
          ? TextSanitizer.sanitize(json['last_message'] as String?)
          : null,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'] as String)
          : null,
      lastSenderId: json['last_sender_id'] as String?,
      lastSenderName: json['last_sender_name'] != null
          ? TextSanitizer.sanitize(json['last_sender_name'] as String?)
          : null,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  final String tripId;
  final String tripTitle;
  final String destination;
  final String hostId;
  final String? hostName;
  final int memberCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isPast;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final String? lastSenderName;
  final int unreadCount;
  final String? coverImageUrl;

  TripChatGroup copyWith({
    String? tripId,
    String? tripTitle,
    String? destination,
    String? hostId,
    String? hostName,
    int? memberCount,
    DateTime? startDate,
    DateTime? endDate,
    bool? isPast,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastSenderId,
    String? lastSenderName,
    int? unreadCount,
    String? coverImageUrl,
  }) {
    return TripChatGroup(
      tripId: tripId ?? this.tripId,
      tripTitle: tripTitle ?? this.tripTitle,
      destination: destination ?? this.destination,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      memberCount: memberCount ?? this.memberCount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isPast: isPast ?? this.isPast,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastSenderName: lastSenderName ?? this.lastSenderName,
      unreadCount: unreadCount ?? this.unreadCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    );
  }
}
