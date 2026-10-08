import '../../features/chats/domain/chat_message.dart';
import 'demo_trips.dart';
import 'demo_users.dart';

/// Authentic group chat data for trips with unlocked chats.
abstract final class DemoChats {
  static final DateTime _now = DateTime.now();

  /// In-memory mutable cache of messages to allow interactive test-messaging during development.
  static final Map<String, List<ChatMessage>> _dynamicMessages = {};

  /// 8–10 Unlocked trip chat channels.
  static List<TripChatGroup> get unlockedTripChats {
    return [
      TripChatGroup(
        tripId: 'trip-alibaug',
        tripTitle: 'Weekend Escape to Alibaug',
        destination: 'Alibaug, Maharashtra',
        hostId: DemoUsers.aarav.id,
        hostName: DemoUsers.aarav.displayName,
        memberCount: 3,
        startDate: _now.add(const Duration(days: 4)),
        endDate: _now.add(const Duration(days: 6)),
        isPast: false,
        unreadCount: 2,
        lastSenderName: 'Aarav',
        lastMessage:
            'Aarav: I will book the 8:00 AM Ro-Pax ferry tickets from Bhaucha Dhakka.',
        lastMessageAt: _now.subtract(const Duration(minutes: 18)),
      ),
      TripChatGroup(
        tripId: 'trip-dudhsagar',
        tripTitle: 'Dudhsagar Waterfalls Monsoon Drive',
        destination: 'Dudhsagar, Goa Border',
        hostId: DemoUsers.currentUser.id,
        hostName: DemoUsers.currentUser.displayName,
        memberCount: 3,
        startDate: _now.add(const Duration(days: 10)),
        endDate: _now.add(const Duration(days: 14)),
        isPast: false,
        unreadCount: 0,
        lastSenderName: 'Kabir',
        lastMessage: 'Kabir: Got the 4x4 booking confirmed with the Kulem forest guide!',
        lastMessageAt: _now.subtract(const Duration(minutes: 42)),
      ),
      TripChatGroup(
        tripId: 'trip-khandala',
        tripTitle: 'Khandala Cliffside Camping & Stargazing',
        destination: 'Khandala, Maharashtra',
        hostId: DemoUsers.currentUser.id,
        hostName: DemoUsers.currentUser.displayName,
        memberCount: 2,
        startDate: _now.add(const Duration(days: 16)),
        endDate: _now.add(const Duration(days: 18)),
        isPast: false,
        unreadCount: 1,
        lastSenderName: 'Riya',
        lastMessage:
            'Riya: Packing my wide-angle lens and tripod for the night sky!',
        lastMessageAt: _now.subtract(const Duration(hours: 2, minutes: 15)),
      ),
      TripChatGroup(
        tripId: 'trip-goa',
        tripTitle: 'Goa Beach & Sunset Weekend',
        destination: 'North Goa',
        hostId: DemoUsers.riya.id,
        hostName: DemoUsers.riya.displayName,
        memberCount: 4,
        startDate: _now.add(const Duration(days: 22)),
        endDate: _now.add(const Duration(days: 25)),
        isPast: false,
        unreadCount: 0,
        lastSenderName: 'Kabir',
        lastMessage:
            'Kabir: Downloaded the offline maps for Amboli ghat route.',
        lastMessageAt: _now.subtract(const Duration(hours: 3, minutes: 30)),
      ),
      TripChatGroup(
        tripId: 'trip-rishikesh',
        tripTitle: 'Rishikesh River Rafting & Cliff Jump',
        destination: 'Rishikesh, Uttarakhand',
        hostId: DemoUsers.siddharth.id,
        hostName: DemoUsers.siddharth.displayName,
        memberCount: 3,
        startDate: _now.add(const Duration(days: 30)),
        endDate: _now.add(const Duration(days: 35)),
        isPast: false,
        unreadCount: 0,
        lastSenderName: 'Siddharth',
        lastMessage:
            'Siddharth: Rapids are flowing high this week, rafting will be epic!',
        lastMessageAt: _now.subtract(const Duration(hours: 5)),
      ),
      TripChatGroup(
        tripId: 'trip-mahabaleshwar',
        tripTitle: 'Road Trip to Mahabaleshwar & Panchgani',
        destination: 'Mahabaleshwar, Maharashtra',
        hostId: DemoUsers.rohan.id,
        hostName: DemoUsers.rohan.displayName,
        memberCount: 3,
        startDate: _now.add(const Duration(days: 40)),
        endDate: _now.add(const Duration(days: 43)),
        isPast: false,
        unreadCount: 0,
        lastSenderName: 'Pooja',
        lastMessage:
            'Pooja: Stop by Mapro garden on Saturday afternoon for fresh strawberry cream?',
        lastMessageAt: _now.subtract(const Duration(hours: 8)),
      ),
      TripChatGroup(
        tripId: 'trip-coorg',
        tripTitle: 'Coorg Coffee Estate Trails',
        destination: 'Coorg, Karnataka',
        hostId: DemoUsers.pooja.id,
        hostName: DemoUsers.pooja.displayName,
        memberCount: 3,
        startDate: _now.add(const Duration(days: 50)),
        endDate: _now.add(const Duration(days: 54)),
        isPast: false,
        unreadCount: 0,
        lastSenderName: 'Pooja',
        lastMessage:
            'Pooja: Homestay host confirmed coffee cupping session for Sunday 10 AM.',
        lastMessageAt: _now.subtract(const Duration(hours: 14)),
      ),
      TripChatGroup(
        tripId: 'trip-lonavala',
        tripTitle: 'Lonavala Sunrise Trek & Waterfalls',
        destination: 'Lonavala & Khandala Ghats',
        hostId: DemoUsers.kunal.id,
        hostName: DemoUsers.kunal.displayName,
        memberCount: 4,
        startDate: _now.subtract(const Duration(days: 15)),
        endDate: _now.subtract(const Duration(days: 13)),
        isPast: true,
        unreadCount: 0,
        lastSenderName: 'Kunal',
        lastMessage:
            'Kunal: Meeting point is Chembur Diamond Garden at 5:15 AM sharp!',
        lastMessageAt: _now.subtract(const Duration(days: 1, hours: 2)),
      ),
      TripChatGroup(
        tripId: 'trip-jaipur',
        tripTitle: 'Jaipur Pink City Heritage Walk',
        destination: 'Jaipur, Rajasthan',
        hostId: DemoUsers.tanvi.id,
        hostName: DemoUsers.tanvi.displayName,
        memberCount: 3,
        startDate: _now.subtract(const Duration(days: 30)),
        endDate: _now.subtract(const Duration(days: 26)),
        isPast: true,
        unreadCount: 0,
        lastSenderName: 'Tanvi',
        lastMessage:
            'Tanvi: Booked the evening light and sound show at Amer Fort.',
        lastMessageAt: _now.subtract(const Duration(days: 1, hours: 6)),
      ),
    ];
  }

  /// Initial seed messages for each trip conversation.
  static List<ChatMessage> _getInitialMessages(String tripId) {
    switch (tripId) {
      case 'trip-alibaug':
        return [
          ChatMessage(
            id: 'msg-ali-1',
            tripId: tripId,
            senderId: DemoUsers.aarav.id,
            senderName: DemoUsers.aarav.displayName,
            senderAvatar: DemoUsers.aarav.avatarPath,
            content:
                'Hey everyone! Welcome to the Alibaug weekend chat! Glad we got our intro calls done so fast.',
            createdAt: _now.subtract(const Duration(hours: 3)),
          ),
          ChatMessage(
            id: 'msg-ali-2',
            tripId: tripId,
            senderId: DemoUsers.currentUser.id,
            senderName: DemoUsers.currentUser.displayName,
            senderAvatar: DemoUsers.currentUser.avatarPath,
            content:
                'Hey Aarav! Excited for this. Should we catch the morning 8:00 AM Ro-Pax ferry from Bhaucha Dhakka?',
            createdAt: _now.subtract(const Duration(hours: 2, minutes: 40)),
          ),
          ChatMessage(
            id: 'msg-ali-3',
            tripId: tripId,
            senderId: DemoUsers.ananya.id,
            senderName: DemoUsers.ananya.displayName,
            senderAvatar: DemoUsers.ananya.avatarPath,
            content:
                '8 AM works great for me! I can reach the dock by 7:30. Already craving coastal seafood and beach sunsets.',
            createdAt: _now.subtract(const Duration(hours: 1, minutes: 15)),
          ),
          ChatMessage(
            id: 'msg-ali-4',
            tripId: tripId,
            senderId: DemoUsers.aarav.id,
            senderName: DemoUsers.aarav.displayName,
            senderAvatar: DemoUsers.aarav.avatarPath,
            content:
                'Aarav: I will book the 8:00 AM Ro-Pax ferry tickets from Bhaucha Dhakka.',
            createdAt: _now.subtract(const Duration(minutes: 18)),
          ),
        ];

      case 'trip-dudhsagar':
        return [
          ChatMessage(
            id: 'msg-dudh-1',
            tripId: tripId,
            senderId: DemoUsers.currentUser.id,
            senderName: DemoUsers.currentUser.displayName,
            senderAvatar: DemoUsers.currentUser.avatarPath,
            content:
                'Welcome aboard Kabir and Ananya! Both of you are confirmed for the Dudhsagar off-road drive.',
            createdAt: _now.subtract(const Duration(hours: 4)),
          ),
          ChatMessage(
            id: 'msg-dudh-2',
            tripId: tripId,
            senderId: DemoUsers.ananya.id,
            senderName: DemoUsers.ananya.displayName,
            senderAvatar: DemoUsers.ananya.avatarPath,
            content:
                'Thanks Omkar! Packing raincoats, waterproof bags, and hiking shoes.',
            createdAt: _now.subtract(const Duration(hours: 2)),
          ),
          ChatMessage(
            id: 'msg-dudh-3',
            tripId: tripId,
            senderId: DemoUsers.kabir.id,
            senderName: DemoUsers.kabir.displayName,
            senderAvatar: DemoUsers.kabir.avatarPath,
            content:
                'Kabir: Got the 4x4 booking confirmed with the Kulem forest guide!',
            createdAt: _now.subtract(const Duration(minutes: 42)),
          ),
        ];

      case 'trip-khandala':
        return [
          ChatMessage(
            id: 'msg-khan-1',
            tripId: tripId,
            senderId: DemoUsers.currentUser.id,
            senderName: DemoUsers.currentUser.displayName,
            senderAvatar: DemoUsers.currentUser.avatarPath,
            content:
                'Hey Riya! Welcome to the Khandala camping trip. Excited to spend a night under the stars.',
            createdAt: _now.subtract(const Duration(hours: 6)),
          ),
          ChatMessage(
            id: 'msg-khan-2',
            tripId: tripId,
            senderId: DemoUsers.riya.id,
            senderName: DemoUsers.riya.displayName,
            senderAvatar: DemoUsers.riya.avatarPath,
            content:
                'Riya: Packing my wide-angle lens and tripod for the night sky!',
            createdAt: _now.subtract(const Duration(hours: 2, minutes: 15)),
          ),
        ];

      case 'trip-goa':
        return [
          ChatMessage(
            id: 'msg-goa-1',
            tripId: tripId,
            senderId: DemoUsers.riya.id,
            senderName: DemoUsers.riya.displayName,
            senderAvatar: DemoUsers.riya.avatarPath,
            content:
                'Hey crew! Who is taking charge of the road trip playlist? 10-hour drive ahead!',
            createdAt: _now.subtract(const Duration(hours: 7)),
          ),
          ChatMessage(
            id: 'msg-goa-2',
            tripId: tripId,
            senderId: DemoUsers.siddharth.id,
            senderName: DemoUsers.siddharth.displayName,
            senderAvatar: DemoUsers.siddharth.avatarPath,
            content:
                'I have an upbeat indie road trip playlist ready. Let\'s make sure we take a food stop near Kolhapur.',
            createdAt: _now.subtract(const Duration(hours: 5)),
          ),
          ChatMessage(
            id: 'msg-goa-3',
            tripId: tripId,
            senderId: DemoUsers.kabir.id,
            senderName: DemoUsers.kabir.displayName,
            senderAvatar: DemoUsers.kabir.avatarPath,
            content:
                'Kabir: Downloaded the offline maps for Amboli ghat route.',
            createdAt: _now.subtract(const Duration(hours: 3, minutes: 30)),
          ),
        ];

      default:
        final trip = DemoTrips.getById(tripId);
        final host = trip != null ? DemoUsers.getById(trip.hostId) : DemoUsers.currentUser;
        return [
          ChatMessage(
            id: 'msg-$tripId-1',
            tripId: tripId,
            senderId: host.id,
            senderName: host.displayName,
            senderAvatar: host.avatarPath,
            content:
                'Hey everyone! Welcome to our trip chat for ${trip?.destination ?? "our journey"}. Feel free to drop questions and coordinate departure.',
            createdAt: _now.subtract(const Duration(days: 1)),
          ),
        ];
    }
  }

  /// Get messages for a trip with dynamic interactive additions.
  static List<ChatMessage> getMessages(String tripId) {
    if (!_dynamicMessages.containsKey(tripId)) {
      _dynamicMessages[tripId] = List.from(_getInitialMessages(tripId));
    }
    return _dynamicMessages[tripId]!;
  }

  /// Add a message dynamically during live UI testing.
  static ChatMessage sendMessage(String tripId, String content) {
    final list = getMessages(tripId);
    final msg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      senderId: DemoUsers.currentUser.id,
      senderName: DemoUsers.currentUser.displayName,
      senderAvatar: DemoUsers.currentUser.avatarPath,
      content: content.trim(),
      createdAt: DateTime.now(),
      status: MessageSendStatus.sent,
    );
    list.add(msg);
    return msg;
  }
}
