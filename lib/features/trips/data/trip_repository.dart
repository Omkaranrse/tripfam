import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/trip.dart';
import '../domain/trip_filter.dart';

abstract interface class TripRepository {
  Future<List<Trip>> getDiscoverTrips({
    TripFilter? filter,
    int limit = 20,
    int offset = 0,
  });

  Future<List<Trip>> getMyTrips();

  Future<Trip?> getTripById(String tripId);

  Future<Trip> createTrip(TripDraft draft);

  Future<Trip> updateTrip(String tripId, TripDraft draft);

  Future<void> cancelTrip(String tripId);

  Future<void> requestToJoin(String tripId, {String? message});

  Future<bool> hasRequestedToJoin(String tripId);

  Future<bool> isTripMember(String tripId);
}

class SupabaseTripRepository implements TripRepository {
  const SupabaseTripRepository(this._client);

  final SupabaseClient? _client;

  // Safe host projection: NEVER pulls home_city, email, or contact details
  static const _safeTripProjection = '''
    id, host_id, destination, start_date, end_date, budget, max_members, description, tags, status, created_at, updated_at,
    host:profiles!host_id(id, display_name, avatar_path, is_verified, travel_style),
    trip_members(id)
  ''';

  @override
  Future<List<Trip>> getDiscoverTrips({
    TripFilter? filter,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_client == null || DemoData.enabled) {
      return _getDemoTrips(filter: filter);
    }

    try {
      var query = _client
          .from('trips')
          .select(_safeTripProjection)
          .eq('status', 'published');

      if (filter != null) {
        if (filter.destinationQuery != null &&
            filter.destinationQuery!.trim().isNotEmpty) {
          final sanitizedQuery = TextSanitizer.sanitize(
            filter.destinationQuery,
          );
          query = query.ilike('destination', '%$sanitizedQuery%');
        }

        if (filter.startDate != null) {
          query = query.gte(
            'start_date',
            filter.startDate!.toIso8601String().split('T').first,
          );
        }

        if (filter.endDate != null) {
          query = query.lte(
            'end_date',
            filter.endDate!.toIso8601String().split('T').first,
          );
        }

        if (filter.minBudget != null) {
          query = query.gte('budget', filter.minBudget!);
        }

        if (filter.maxBudget != null) {
          query = query.lte('budget', filter.maxBudget!);
        }

        if (filter.tags.isNotEmpty) {
          query = query.contains('tags', filter.tags.toList());
        }
      }

      final response = await query
          .order('start_date', ascending: true)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => Trip.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // In demo mode or if Supabase isn't reachable, return offline sample trips
      return _getDemoTrips(filter: filter);
    }
  }

  @override
  Future<List<Trip>> getMyTrips() async {
    if (_client == null || DemoData.enabled) {
      const currentUserId = DemoData.currentUserId;
      return DemoTrips.all.where((t) {
        return t.hostId == currentUserId ||
            t.id == 'trip-alibaug' ||
            t.id == 'trip-pawna';
      }).toList();
    }

    final user = _client.auth.currentUser;
    if (user == null) return const [];

    try {
      final response = await _client
          .from('trips')
          .select(_safeTripProjection)
          .eq('host_id', user.id)
          .order('start_date', ascending: true);

      return (response as List)
          .map((json) => Trip.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Trip?> getTripById(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return DemoTrips.getById(tripId);
    }

    try {
      final response = await _client
          .from('trips')
          .select(_safeTripProjection)
          .eq('id', tripId)
          .maybeSingle();

      if (response == null) {
        return DemoTrips.getById(tripId);
      }
      return Trip.fromJson(response);
    } catch (_) {
      return DemoTrips.getById(tripId);
    }
  }

  @override
  Future<Trip> createTrip(TripDraft draft) async {
    if (_client == null) {
      throw Exception('Sign-in required to host a trip.');
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign-in required to host a trip.');
    }

    final validationError = draft.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    try {
      final insertData = draft.toInsertJson(user.id);
      final response = await _client
          .from('trips')
          .insert(insertData)
          .select(_safeTripProjection)
          .single();

      final created = Trip.fromJson(response);

      // Automatically register host in trip_members
      await _client.from('trip_members').insert({
        'trip_id': created.id,
        'user_id': user.id,
        'role': 'host',
      });

      return created;
    } catch (_) {
      throw Exception('Failed to create trip. Please try again.');
    }
  }

  @override
  Future<Trip> updateTrip(String tripId, TripDraft draft) async {
    if (_client == null) {
      throw Exception('Sign-in required to edit a trip.');
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign-in required to edit a trip.');
    }

    final validationError = draft.validate();
    if (validationError != null) {
      throw Exception(validationError);
    }

    // Verify confirmed members exist before allowing changes to critical fields
    final existing = await getTripById(tripId);
    if (existing == null) {
      throw Exception('Trip not found.');
    }

    if (existing.hostId != user.id) {
      throw Exception('Only the trip host can edit this trip.');
    }

    if (existing.hasConfirmedMembers) {
      final destinationChanged =
          TextSanitizer.sanitize(existing.destination) !=
          TextSanitizer.sanitize(draft.destination);
      final datesChanged =
          existing.startDate != draft.startDate ||
          existing.endDate != draft.endDate;

      if (destinationChanged || datesChanged) {
        throw Exception(
          'Cannot modify trip dates or destination once fellow travellers have joined.',
        );
      }
    }

    try {
      final response = await _client
          .from('trips')
          .update({
            'destination': TextSanitizer.sanitize(draft.destination),
            'start_date': draft.startDate.toIso8601String().split('T').first,
            'end_date': draft.endDate.toIso8601String().split('T').first,
            'budget': draft.budget,
            'max_members': draft.maxMembers,
            'description': TextSanitizer.sanitize(draft.description),
            'tags': draft.tags.map(TextSanitizer.sanitize).toList(),
          })
          .eq('id', tripId)
          .eq('host_id', user.id)
          .select(_safeTripProjection)
          .single();

      return Trip.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update trip: ${e.toString()}');
    }
  }

  @override
  Future<void> cancelTrip(String tripId) async {
    if (_client == null) {
      throw Exception('Sign-in required to cancel a trip.');
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign-in required to cancel a trip.');
    }

    try {
      await _client
          .from('trips')
          .update({'status': 'cancelled'})
          .eq('id', tripId)
          .eq('host_id', user.id);
    } catch (_) {
      throw Exception('Failed to cancel trip. Please try again.');
    }
  }

  @override
  Future<void> requestToJoin(String tripId, {String? message}) async {
    if (_client == null || DemoData.enabled) {
      return;
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Sign-in required to request joining a trip.');
    }

    try {
      await _client.from('join_requests').insert({
        'trip_id': tripId,
        'user_id': user.id,
        'status': 'pending',
        'message': TextSanitizer.sanitize(message),
      });
    } catch (_) {
      throw Exception(
        'Unable to submit request. You may have an existing request.',
      );
    }
  }

  @override
  Future<bool> hasRequestedToJoin(String tripId) async {
    if (_client == null || DemoData.enabled) {
      return DemoRequests.getMyRequestForTrip(tripId) != null;
    }

    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _client
          .from('join_requests')
          .select('id')
          .eq('trip_id', tripId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isTripMember(String tripId) async {
    if (_client == null || DemoData.enabled) {
      final trip = DemoTrips.getById(tripId);
      if (trip == null) return false;
      return trip.hostId == DemoData.currentUserId || tripId == 'trip-alibaug';
    }

    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await _client
          .from('trip_members')
          .select('id')
          .eq('trip_id', tripId)
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false;
    }
  }

  List<Trip> _getDemoTrips({TripFilter? filter}) {
    final demoTrips = DemoTrips.all;

    if (filter == null) return demoTrips;

    return demoTrips.where((t) {
      if (filter.destinationQuery != null &&
          filter.destinationQuery!.trim().isNotEmpty) {
        final query = filter.destinationQuery!.trim().toLowerCase();
        final matches = t.destination.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query) ||
            t.tags.any((tag) => tag.toLowerCase().contains(query));
        if (!matches) return false;
      }
      if (filter.startDate != null) {
        if (t.startDate.isBefore(filter.startDate!)) return false;
      }
      if (filter.endDate != null) {
        if (t.endDate.isAfter(filter.endDate!)) return false;
      }
      if (filter.minBudget != null &&
          (t.budget == null || t.budget! < filter.minBudget!)) {
        return false;
      }
      if (filter.maxBudget != null &&
          (t.budget == null || t.budget! > filter.maxBudget!)) {
        return false;
      }
      if (filter.tags.isNotEmpty) {
        final matchesTag = filter.tags.any((filterTag) {
          final filterLower = filterTag.toLowerCase();
          return t.tags.any((tripTag) =>
              tripTag.toLowerCase() == filterLower ||
              tripTag.toLowerCase().contains(filterLower) ||
              filterLower.contains(tripTag.toLowerCase()));
        });
        if (!matchesTag) return false;
      }
      return true;
    }).toList();
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseTripRepository(client);
});

final tripFilterProvider = StateProvider<TripFilter>(
  (ref) => const TripFilter(),
);

final discoverTripsProvider = FutureProvider<List<Trip>>((ref) {
  final filter = ref.watch(tripFilterProvider);
  return ref.watch(tripRepositoryProvider).getDiscoverTrips(filter: filter);
});

final myTripsProvider = FutureProvider<List<Trip>>((ref) {
  return ref.watch(tripRepositoryProvider).getMyTrips();
});

final tripDetailProvider = FutureProvider.family<Trip?, String>((ref, tripId) {
  return ref.watch(tripRepositoryProvider).getTripById(tripId);
});
