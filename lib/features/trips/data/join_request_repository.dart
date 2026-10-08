import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/meeting_link_validator.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/join_request.dart';

abstract interface class JoinRequestRepository {
  Future<JoinRequest> sendJoinRequest(String tripId, {String? message});

  Future<void> cancelJoinRequest(String requestId);

  Future<List<JoinRequest>> getTripJoinRequests(String tripId);

  Future<List<JoinRequest>> getMyJoinRequests();

  Future<JoinRequest?> getRequestForTrip(String tripId);

  Future<void> acceptJoinRequest(String requestId);

  Future<void> declineJoinRequest(String requestId);

  Future<IntroCall> scheduleIntroCall(
    String introCallId, {
    required DateTime scheduledAt,
    required String meetingLink,
  });

  Future<bool> confirmIntroCall(String introCallId);
}

class SupabaseJoinRequestRepository implements JoinRequestRepository {
  const SupabaseJoinRequestRepository(this._client);

  final SupabaseClient? _client;

  // Safe projection: NEVER exposes applicant's home city or email
  static const _safeJoinRequestProjection = '''
    id, trip_id, user_id, status, message, created_at, updated_at,
    profile:profiles!user_id(id, display_name, avatar_path, is_verified, travel_style),
    intro_calls(id, request_id, scheduled_at, meeting_link, host_confirmed, traveller_confirmed, created_at, updated_at),
    trip:trips!trip_id(id, destination, host_id)
  ''';

  @override
  Future<JoinRequest> sendJoinRequest(String tripId, {String? message}) async {
    final sanitizedMessage = TextSanitizer.sanitize(message);

    if (_client == null || DemoData.enabled) {
      final req = JoinRequest(
        id: 'req-demo-${DateTime.now().millisecondsSinceEpoch}',
        tripId: tripId,
        userId: DemoData.currentUserId,
        status: 'pending',
        message: sanitizedMessage,
        createdAt: DateTime.now(),
        applicant: ApplicantProfile(
          id: DemoUsers.currentUser.id,
          displayName: DemoUsers.currentUser.displayName,
          avatarPath: DemoUsers.currentUser.avatarPath,
          isVerified: DemoUsers.currentUser.isVerified,
          travelStyle: DemoUsers.currentUser.travelStyle,
        ),
      );
      DemoRequests.recordDemoRequest(req);
      return req;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign-in required to request joining a trip.');
    }

    try {
      final response = await _client
          .from('join_requests')
          .insert({
            'trip_id': tripId,
            'user_id': user.id,
            'status': 'pending',
            'message': sanitizedMessage,
          })
          .select(_safeJoinRequestProjection)
          .single();

      return JoinRequest.fromJson(response);
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('uq_join_requests_trip_user') ||
          errorStr.contains('duplicate key')) {
        throw Exception('You have already submitted a request for this trip.');
      }
      if (errorStr.contains('limit reached') || errorStr.contains('23514')) {
        throw Exception(
          'Daily join request limit reached (10 requests per 24 hours). Please try again tomorrow.',
        );
      }
      throw Exception(
        'Unable to submit request: ${TextSanitizer.sanitize(e.toString())}',
      );
    }
  }

  @override
  Future<void> cancelJoinRequest(String requestId) async {
    if (_client == null || DemoData.enabled) {
      return;
    }

    try {
      await _client.rpc<dynamic>(
        'cancel_join_request',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw Exception(
        'Failed to cancel request: ${TextSanitizer.sanitize(e.toString())}',
      );
    }
  }

  @override
  Future<List<JoinRequest>> getTripJoinRequests(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return DemoRequests.getRequestsForTrip(tripId);
    }

    try {
      final response = await _client
          .from('join_requests')
          .select(_safeJoinRequestProjection)
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => JoinRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<JoinRequest>> getMyJoinRequests() async {
    if (_client == null || DemoData.enabled) {
      return DemoRequests.myOutgoingRequests;
    }

    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await _client
          .from('join_requests')
          .select(_safeJoinRequestProjection)
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => JoinRequest.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<JoinRequest?> getRequestForTrip(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return DemoRequests.getMyRequestForTrip(tripId);
    }

    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('join_requests')
          .select(_safeJoinRequestProjection)
          .eq('trip_id', tripId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return null;
      return JoinRequest.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> acceptJoinRequest(String requestId) async {
    if (_client == null || DemoData.enabled) {
      return;
    }

    try {
      await _client.rpc<dynamic>(
        'accept_join_request',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      final err = e.toString();
      if (err.contains('capacity limit')) {
        throw Exception('This trip has reached its maximum member capacity.');
      }
      throw Exception(
        'Failed to accept request: ${TextSanitizer.sanitize(e.toString())}',
      );
    }
  }

  @override
  Future<void> declineJoinRequest(String requestId) async {
    if (_client == null || DemoData.enabled) {
      return;
    }

    try {
      await _client.rpc<dynamic>(
        'decline_join_request',
        params: {'p_request_id': requestId},
      );
    } catch (e) {
      throw Exception(
        'Failed to decline request: ${TextSanitizer.sanitize(e.toString())}',
      );
    }
  }

  @override
  Future<IntroCall> scheduleIntroCall(
    String introCallId, {
    required DateTime scheduledAt,
    required String meetingLink,
  }) async {
    final linkValidation = MeetingLinkValidator.validate(meetingLink);
    if (linkValidation != null) {
      throw Exception(linkValidation);
    }

    if (scheduledAt.isBefore(
      DateTime.now().subtract(const Duration(minutes: 5)),
    )) {
      throw Exception('Scheduled call time must be in the future.');
    }

    if (_client == null || DemoData.enabled) {
      return IntroCall(
        id: introCallId,
        requestId: 'req-demo',
        scheduledAt: scheduledAt,
        meetingLink: meetingLink,
        hostConfirmed: true,
        travellerConfirmed: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    try {
      await _client.rpc<dynamic>(
        'schedule_intro_call',
        params: {
          'p_intro_call_id': introCallId,
          'p_scheduled_at': scheduledAt.toIso8601String(),
          'p_meeting_link': meetingLink.trim(),
        },
      );

      final updated = await _client
          .from('intro_calls')
          .select()
          .eq('id', introCallId)
          .single();

      return IntroCall.fromJson(updated);
    } catch (e) {
      throw Exception(
        'Failed to schedule call: ${TextSanitizer.sanitize(e.toString())}',
      );
    }
  }

  @override
  Future<bool> confirmIntroCall(String introCallId) async {
    if (_client == null || DemoData.enabled) {
      return true;
    }

    try {
      final response = await _client.rpc<dynamic>(
        'confirm_intro_call',
        params: {'p_intro_call_id': introCallId},
      );

      final data = response as Map<String, dynamic>?;
      return data?['chat_unlocked'] as bool? ?? false;
    } catch (e) {
      throw Exception(
        'Failed to confirm call: ${TextSanitizer.sanitize(e.toString())}',
      );
    }
  }
}

final joinRequestRepositoryProvider = Provider<JoinRequestRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseJoinRequestRepository(client);
});

final tripJoinRequestsProvider =
    FutureProvider.family<List<JoinRequest>, String>((ref, tripId) {
      return ref
          .watch(joinRequestRepositoryProvider)
          .getTripJoinRequests(tripId);
    });

final myJoinRequestsProvider = FutureProvider<List<JoinRequest>>((ref) {
  return ref.watch(joinRequestRepositoryProvider).getMyJoinRequests();
});

final userTripRequestProvider = FutureProvider.family<JoinRequest?, String>((
  ref,
  tripId,
) {
  return ref.watch(joinRequestRepositoryProvider).getRequestForTrip(tripId);
});
