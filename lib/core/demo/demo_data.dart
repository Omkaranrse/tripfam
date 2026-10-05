import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'demo_chats.dart';
export 'demo_images.dart';
export 'demo_requests.dart';
export 'demo_safety.dart';
export 'demo_trips.dart';
export 'demo_users.dart';

/// Master configuration for TripMate's demo/dummy data mode.
/// Setting [enabled] to `true` powers the application with an authentic
/// Mumbai-first travel community dataset without touching Supabase production tables.
abstract final class DemoData {
  /// Master toggle for demo mode.
  /// Set to false to switch exclusively to live Supabase backend data.
  static bool enabled = true;

  /// Identifier for the current logged-in demo traveller.
  static const String currentUserId = 'user-omkar';
}

/// Riverpod provider for reactive demo mode toggling across the UI.
final demoModeProvider = StateProvider<bool>((ref) => DemoData.enabled);
