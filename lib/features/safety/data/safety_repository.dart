import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/safety_models.dart';

abstract interface class SafetyRepository {
  Future<List<TrustedContact>> getTrustedContacts();

  Future<TrustedContact> addTrustedContact({
    required String name,
    String? phone,
    String? email,
    String? relationship,
  });

  Future<void> deleteTrustedContact(String contactId);

  Future<TripCheckinSchedule?> getTripCheckinSchedule(String tripId);

  Future<Map<String, dynamic>> recordCheckIn(
    String tripId, {
    String? locationName,
    double? latitude,
    double? longitude,
  });

  Future<void> setCheckinInterval(String tripId, int intervalHours);

  Future<TripLiveLocation?> getLiveLocation(String tripId);

  Future<void> setLiveLocationSharing(
    String tripId,
    bool enabled, {
    double? latitude,
    double? longitude,
    double? accuracy,
  });

  Future<List<BlockedUser>> getBlockedUsers();

  Future<void> unblockUser(String userId);

  Future<void> submitReport({
    required String reason,
    required String details,
    String? reportedUserId,
    String? tripId,
  });
}

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<List<TrustedContact>> getTrustedContacts() async {
    if (_client == null || DemoData.enabled) {
      return DemoSafety.trustedContacts;
    }
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await _client
          .from('trusted_contacts')
          .select('id, name, relationship, phone_number, email')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      final list = response as List<dynamic>;
      return list
          .map((item) => TrustedContact.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<TrustedContact> addTrustedContact({
    required String name,
    String? phone,
    String? email,
    String? relationship,
  }) async {
    if (_client == null || DemoData.enabled) {
      return TrustedContact(
        id: 'contact-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        relationship: relationship ?? 'Emergency Contact',
        phoneNumber: phone,
        email: email,
      );
    }

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final cleanName = TextSanitizer.limit(name, 100);
    if (cleanName.length < 2) {
      throw Exception('Contact name must be at least 2 characters.');
    }

    final cleanPhone = phone?.trim();
    final cleanEmail = email?.trim();

    if ((cleanPhone == null || cleanPhone.isEmpty) &&
        (cleanEmail == null || cleanEmail.isEmpty)) {
      throw Exception(
        'Please provide either a phone number or an email address.',
      );
    }

    try {
      final response = await _client
          .from('trusted_contacts')
          .insert({
            'user_id': user.id,
            'name': cleanName,
            'relationship': relationship?.trim().isNotEmpty == true
                ? TextSanitizer.limit(relationship, 50)
                : 'Emergency Contact',
            'phone_number': cleanPhone?.isNotEmpty == true ? cleanPhone : null,
            'email': cleanEmail?.isNotEmpty == true ? cleanEmail : null,
          })
          .select()
          .single();

      return TrustedContact.fromJson(response);
    } catch (e) {
      final err = e.toString();
      if (err.contains('up to 3')) {
        throw Exception('You can only have up to 3 trusted contacts.');
      }
      throw Exception('Failed to add contact. Please check your inputs.');
    }
  }

  @override
  Future<void> deleteTrustedContact(String contactId) async {
    if (_client == null || DemoData.enabled) return;
    try {
      await _client.from('trusted_contacts').delete().eq('id', contactId);
    } catch (e) {
      throw Exception('Unable to remove contact: ${e.toString()}');
    }
  }

  @override
  Future<TripCheckinSchedule?> getTripCheckinSchedule(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return DemoSafety.checkinSchedule;
    }
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('trip_checkin_schedules')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return TripCheckinSchedule.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, dynamic>> recordCheckIn(
    String tripId, {
    String? locationName,
    double? latitude,
    double? longitude,
  }) async {
    if (_client == null || DemoData.enabled) {
      return {'success': true, 'message': 'Safe check-in recorded!'};
    }

    try {
      final response = await _client.rpc<dynamic>(
        'record_trip_checkin',
        params: {
          'p_trip_id': tripId,
          'p_location_name': locationName ?? 'Manual Safe Check-In',
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );

      return (response as Map<String, dynamic>?) ?? {};
    } catch (e) {
      throw Exception('Failed to record check-in: ${e.toString()}');
    }
  }

  @override
  Future<void> setCheckinInterval(String tripId, int intervalHours) async {
    if (_client == null || DemoData.enabled) return;

    try {
      await _client.rpc<dynamic>(
        'set_trip_checkin_interval',
        params: {'p_trip_id': tripId, 'p_interval_hours': intervalHours},
      );
    } catch (e) {
      throw Exception('Unable to update interval: ${e.toString()}');
    }
  }

  @override
  Future<TripLiveLocation?> getLiveLocation(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return DemoSafety.liveLocation;
    }
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('trip_live_locations')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return TripLiveLocation.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setLiveLocationSharing(
    String tripId,
    bool enabled, {
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    if (_client == null || DemoData.enabled) return;

    try {
      await _client.rpc<dynamic>(
        'set_live_location_sharing',
        params: {
          'p_trip_id': tripId,
          'p_enabled': enabled,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_accuracy': accuracy,
        },
      );
    } catch (e) {
      throw Exception('Unable to update live location: ${e.toString()}');
    }
  }

  @override
  Future<List<BlockedUser>> getBlockedUsers() async {
    if (_client == null || DemoData.enabled) {
      return DemoSafety.blockedUsers;
    }
    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await _client
          .from('blocks')
          .select('''
            id,
            blocked_id,
            created_at,
            blocked_profile:profiles!blocks_blocked_id_fkey(
              id,
              display_name,
              avatar_path
            )
          ''')
          .eq('blocker_id', user.id)
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((item) => BlockedUser.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    if (_client == null || DemoData.enabled) return;

    try {
      await _client.rpc<dynamic>(
        'unblock_user',
        params: {'p_blocked_id': userId},
      );
    } catch (e) {
      throw Exception('Unable to unblock user: ${e.toString()}');
    }
  }

  @override
  Future<void> submitReport({
    required String reason,
    required String details,
    String? reportedUserId,
    String? tripId,
  }) async {
    if (_client == null || DemoData.enabled) return;

    final cleanReason = TextSanitizer.limit(reason, 100);
    final cleanDetails = TextSanitizer.limit(details, 2000);

    if (cleanReason.isEmpty) {
      throw Exception('Reason is required.');
    }

    try {
      if (reportedUserId != null) {
        await _client.rpc<dynamic>(
          'report_user',
          params: {
            'p_reported_user_id': reportedUserId,
            'p_reason': cleanReason,
            'p_details': cleanDetails,
            'p_trip_id': tripId,
          },
        );
      } else {
        // Direct insert for general or trip report
        final user = _client.auth.currentUser;
        if (user == null) throw Exception('User not signed in.');

        await _client.from('reports').insert({
          'reporter_id': user.id,
          'trip_id': tripId,
          'reason': cleanReason,
          'details': cleanDetails,
        });
      }
    } catch (e) {
      throw Exception('Failed to submit report: ${e.toString()}');
    }
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final safetyRepositoryProvider = Provider<SafetyRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseSafetyRepository(client);
});

final trustedContactsProvider = FutureProvider<List<TrustedContact>>((ref) {
  return ref.watch(safetyRepositoryProvider).getTrustedContacts();
});

final blockedUsersListProvider = FutureProvider<List<BlockedUser>>((ref) {
  return ref.watch(safetyRepositoryProvider).getBlockedUsers();
});

final tripCheckinScheduleProvider =
    FutureProvider.family<TripCheckinSchedule?, String>((ref, tripId) {
      return ref.watch(safetyRepositoryProvider).getTripCheckinSchedule(tripId);
    });

final liveLocationProvider = FutureProvider.family<TripLiveLocation?, String>((
  ref,
  tripId,
) {
  return ref.watch(safetyRepositoryProvider).getLiveLocation(tripId);
});
