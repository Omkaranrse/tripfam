import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/trip.dart';
import 'trip_repository.dart';

abstract interface class SavedTripRepository {
  Future<List<Trip>> getSavedTrips();
  Future<Set<String>> getSavedTripIds();
  Future<void> saveTrip(String tripId);
  Future<void> unsaveTrip(String tripId);
}

class SupabaseSavedTripRepository implements SavedTripRepository {
  SupabaseSavedTripRepository(this._client, this._tripRepo, this._prefs);

  final SupabaseClient? _client;
  final TripRepository _tripRepo;
  final SharedPreferences _prefs;

  static const _localSavedTripsKey = 'tripfam_local_saved_trips_v1';

  Set<String> _readLocalSavedIds() {
    final raw = _prefs.getStringList(_localSavedTripsKey);
    return raw?.toSet() ?? {};
  }

  Future<void> _writeLocalSavedIds(Set<String> ids) async {
    await _prefs.setStringList(_localSavedTripsKey, ids.toList());
  }

  @override
  Future<Set<String>> getSavedTripIds() async {
    if (_client == null || DemoData.enabled) {
      return _readLocalSavedIds();
    }

    try {
      final user = _client.auth.currentUser;
      if (user == null) return _readLocalSavedIds();

      final res = await _client
          .from('saved_trips')
          .select('trip_id')
          .eq('user_id', user.id);

      final list = (res as List)
          .map((row) => (row as Map)['trip_id'] as String)
          .toSet();
      // Sync local cache
      await _writeLocalSavedIds(list);
      return list;
    } catch (_) {
      return _readLocalSavedIds();
    }
  }

  @override
  Future<List<Trip>> getSavedTrips() async {
    if (_client == null || DemoData.enabled) {
      final ids = _readLocalSavedIds();
      final allTrips = await _tripRepo.getDiscoverTrips();
      return allTrips.where((t) => ids.contains(t.id)).toList();
    }

    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        final ids = _readLocalSavedIds();
        final allTrips = await _tripRepo.getDiscoverTrips();
        return allTrips.where((t) => ids.contains(t.id)).toList();
      }

      final res = await _client
          .from('saved_trips')
          .select('''
            trip_id,
            trip:trips(
              id, host_id, destination, start_date, end_date, budget, max_members, description, tags, status, created_at, updated_at,
              host:profiles!host_id(id, display_name, avatar_path, is_verified, travel_style),
              trip_members(id)
            )
          ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final trips = <Trip>[];
      final ids = <String>{};
      for (final row in res as List) {
        final tripMap = (row as Map)['trip'] as Map<String, dynamic>?;
        if (tripMap != null) {
          trips.add(Trip.fromJson(tripMap));
          ids.add((row)['trip_id'] as String);
        }
      }
      await _writeLocalSavedIds(ids);
      return trips;
    } catch (_) {
      // Offline fallback
      final ids = _readLocalSavedIds();
      final allTrips = await _tripRepo.getDiscoverTrips();
      return allTrips.where((t) => ids.contains(t.id)).toList();
    }
  }

  @override
  Future<void> saveTrip(String tripId) async {
    final ids = _readLocalSavedIds()..add(tripId);
    await _writeLocalSavedIds(ids);

    if (_client != null && !DemoData.enabled) {
      final user = _client.auth.currentUser;
      if (user != null) {
        try {
          await _client.from('saved_trips').upsert({
            'user_id': user.id,
            'trip_id': tripId,
          });
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> unsaveTrip(String tripId) async {
    final ids = _readLocalSavedIds()..remove(tripId);
    await _writeLocalSavedIds(ids);

    if (_client != null && !DemoData.enabled) {
      final user = _client.auth.currentUser;
      if (user != null) {
        try {
          await _client
              .from('saved_trips')
              .delete()
              .eq('user_id', user.id)
              .eq('trip_id', tripId);
        } catch (_) {}
      }
    }
  }
}

final savedTripRepositoryProvider = Provider<SavedTripRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final tripRepo = ref.watch(tripRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return SupabaseSavedTripRepository(client, tripRepo, prefs);
});
