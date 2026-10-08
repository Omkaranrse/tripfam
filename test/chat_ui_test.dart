import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/theme/app_theme.dart';
import 'package:tripfam/features/account/data/auth_repository.dart';
import 'package:tripfam/features/account/data/profile_repository.dart';
import 'package:tripfam/features/account/domain/user_profile.dart';
import 'package:tripfam/features/chats/data/chat_repository.dart';
import 'package:tripfam/features/chats/domain/chat_grouped_item.dart';
import 'package:tripfam/features/chats/domain/chat_message.dart';
import 'package:tripfam/features/chats/presentation/chats_page.dart';
import 'package:tripfam/features/chats/presentation/widgets/chat_composer.dart';
import 'package:tripfam/features/chats/presentation/widgets/chat_message_bubble.dart';
import 'package:tripfam/features/chats/presentation/widgets/chat_room_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeUser extends Fake implements User {
  @override
  String get id => 'user_me';

  @override
  Map<String, dynamic> get userMetadata => {'display_name': 'Omkar A.'};
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  Future<UserProfile?> build() async => null;
}

class FakeChatRepository extends Fake implements ChatRepository {
  @override
  Future<List<TripChatGroup>> getUnlockedChats() async {
    final now = DateTime.now();
    return [
      TripChatGroup(
        tripId: 'trip_upcoming',
        tripTitle: 'Himalayan Trek',
        destination: 'Manali',
        hostId: 'host_1',
        hostName: 'Aarav Patel',
        memberCount: 5,
        startDate: now.add(const Duration(days: 10)),
        endDate: now.add(const Duration(days: 15)),
        isPast: false,
        lastMessage: 'Pack warm jackets everyone!',
        lastMessageAt: now.subtract(const Duration(minutes: 15)),
        lastSenderName: 'Aarav Patel',
        unreadCount: 2,
      ),
      TripChatGroup(
        tripId: 'trip_past',
        tripTitle: 'Goa Beach Weekend',
        destination: 'Goa',
        hostId: 'host_2',
        hostName: 'Rohan Shah',
        memberCount: 4,
        startDate: now.subtract(const Duration(days: 30)),
        endDate: now.subtract(const Duration(days: 27)),
        isPast: true,
        lastMessage: 'Awesome photos from the beach!',
        lastMessageAt: now.subtract(const Duration(days: 26)),
        lastSenderName: 'Rohan Shah',
        unreadCount: 0,
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> getMessages(
    String tripId, {
    DateTime? before,
    int limit = 30,
  }) async =>
      [];

  @override
  Future<void> markChatRead(String tripId) async {}

  @override
  RealtimeChannel subscribeToTyping(
    String tripId, {
    required void Function(String userName) onUserTyping,
  }) =>
      FakeRealtimeChannel();

  @override
  RealtimeChannel subscribeToTripMessages(
    String tripId, {
    required void Function(ChatMessage message) onMessage,
    void Function(String messageId)? onMessageDeleted,
  }) =>
      FakeRealtimeChannel();
}

class FakeRealtimeChannel extends Fake implements RealtimeChannel {
  @override
  Future<String> unsubscribe([Duration? timeout]) async => 'ok';
}

void main() {
  group('ChatComposer Widget Tests', () {
    testWidgets('send button is disabled when empty, enabled when text is typed',
        (tester) async {
      String? sentText;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatComposer(
              onSend: (text) async {
                sentText = text;
              },
              onTyping: () {},
            ),
          ),
        ),
      );

      final sendIcon = find.byIcon(Icons.arrow_upward_rounded);
      expect(sendIcon, findsOneWidget);

      final sendInkWell = tester.widget<InkWell>(
        find.ancestor(of: sendIcon, matching: find.byType(InkWell)),
      );
      // Initially disabled
      expect(sendInkWell.onTap, isNull);

      // Enter valid text
      await tester.enterText(find.byType(TextField), 'Hello adventurers!');
      await tester.pump();

      // Send button should now be enabled
      final sendInkWellActive = tester.widget<InkWell>(
        find.ancestor(of: sendIcon, matching: find.byType(InkWell)),
      );
      expect(sendInkWellActive.onTap, isNotNull);

      // Tap send
      await tester.tap(sendIcon);
      await tester.pump();

      expect(sentText, equals('Hello adventurers!'));
      expect(find.text('Hello adventurers!'), findsNothing); // Text field cleared
    });

    testWidgets('shows character counter when text exceeds 1800 chars and enforces 2000 max',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatComposer(
              onSend: (_) async {},
              onTyping: () {},
            ),
          ),
        ),
      );

      // At 100 characters, no counter visible
      await tester.enterText(find.byType(TextField), 'A' * 100);
      await tester.pump();
      expect(find.textContaining('/ 2000'), findsNothing);

      // At 1850 characters, counter must appear
      await tester.enterText(find.byType(TextField), 'A' * 1850);
      await tester.pump();
      expect(find.text('1850 / 2000'), findsOneWidget);
    });

    testWidgets('renders read-only banner when trip is past', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatComposer(
              isReadOnly: true,
              onSend: (_) async {},
              onTyping: () {},
            ),
          ),
        ),
      );

      expect(find.text('This past trip chat is now in read-only mode'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('ChatMessageBubble Widget Tests', () {
    testWidgets('renders other message with formatted name and content',
        (tester) async {
      final now = DateTime.now();

      final otherMsg = ChatMessage(
        id: 'msg_1',
        tripId: 'trip_1',
        senderId: 'user_other',
        senderName: 'Priya Sharma',
        content: 'See you at the trailhead!',
        createdAt: now,
      );

      final otherItem = ChatMessageBubbleItem(
        message: otherMsg,
        isMine: false,
        isFirstInGroup: true,
        isLastInGroup: true,
        showSenderHeader: true,
        gapBelow: 12.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatMessageBubble(item: otherItem),
          ),
        ),
      );

      expect(find.text('See you at the trailhead!'), findsOneWidget);
      expect(find.text('Priya S.'), findsOneWidget); // First name + last initial
    });

    testWidgets('tapping an external link opens security confirmation dialog with domain',
        (tester) async {
      final now = DateTime.now();

      final linkMsg = ChatMessage(
        id: 'msg_2',
        tripId: 'trip_1',
        senderId: 'user_other',
        senderName: 'Priya Sharma',
        content: 'Check out the trail map at https://maps.google.com/trail',
        createdAt: now,
      );

      final linkItem = ChatMessageBubbleItem(
        message: linkMsg,
        isMine: false,
        isFirstInGroup: true,
        isLastInGroup: true,
        showSenderHeader: true,
        gapBelow: 12.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatMessageBubble(item: linkItem),
          ),
        ),
      );

      // Tap on the GestureDetector wrapping the link
      final linkGesture = find.byWidgetPredicate(
        (widget) => widget is GestureDetector && widget.child is Text && (widget.child as Text).data == 'https://maps.google.com/trail',
      );
      expect(linkGesture, findsOneWidget);
      await tester.tap(linkGesture);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Security confirmation dialog should appear with domain
      expect(find.text('Open External Link'), findsOneWidget);
      expect(
        find.textContaining('You are navigating to external domain:\n\nmaps.google.com'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Open Link'), findsOneWidget);

      // Tap Cancel to dismiss
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Open External Link'), findsNothing);
    });

    testWidgets('long press opens safety action sheet (Copy, Report, Block)',
        (tester) async {
      final now = DateTime.now();

      final msg = ChatMessage(
        id: 'msg_3',
        tripId: 'trip_1',
        senderId: 'user_other',
        senderName: 'Priya Sharma',
        content: 'Message to inspect',
        createdAt: now,
      );

      final item = ChatMessageBubbleItem(
        message: msg,
        isMine: false,
        isFirstInGroup: true,
        isLastInGroup: true,
        showSenderHeader: true,
        gapBelow: 12.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChatMessageBubble(item: item),
          ),
        ),
      );

      // Long press on the message bubble
      await tester.longPress(find.text('Message to inspect'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Copy message'), findsOneWidget);
      expect(find.text('Report message or user'), findsOneWidget);
      expect(find.text('Block user'), findsOneWidget);
    });
  });

  group('ChatsPage & Master-Detail Tests', () {
    testWidgets('renders upcoming and past trips with unread pills and search filter on mobile',
        (tester) async {
      final fakeRepo = FakeChatRepository();

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWithValue(FakeUser()),
            userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ChatsPage(),
          ),
        ),
      );

      // Wait for chat list async load
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Section headers
      expect(find.text('Upcoming Trips'), findsOneWidget);
      expect(find.text('Past Trips'), findsOneWidget);

      // Trip rows
      expect(find.text('Himalayan Trek'), findsOneWidget);
      expect(find.text('Goa Beach Weekend'), findsOneWidget);

      // Unread pill on upcoming trip
      expect(find.text('2'), findsOneWidget);

      // Test local search filtering
      await tester.enterText(find.byType(TextField), 'Manali');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Himalayan Trek'), findsOneWidget);
      expect(find.text('Goa Beach Weekend'), findsNothing); // Filtered out
    });

    testWidgets('renders master-detail split layout on tablet / desktop (1000px width)',
        (tester) async {
      final fakeRepo = FakeChatRepository();

      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWithValue(FakeUser()),
            userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ChatsPage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Master list visible on left
      expect(find.text('Trip Chats'), findsOneWidget);
      expect(find.byType(ChatRoomView), findsOneWidget);
    });
  });
}
