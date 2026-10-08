import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/app_providers.dart';

/// Local device-only storage for dismissed trips.
/// Stored with timestamps and expired automatically after 30 days.
/// Never communicated to the server.
class DismissedTripsStorage {
  DismissedTripsStorage(this._prefs);

  final SharedPreferences _prefs;
  static const _storageKey = 'tripfam_dismissed_trips_v1';
  static const int _expiryDurationMs = 30 * 24 * 60 * 60 * 1000; // 30 days

  Map<String, int> _readRaw() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _writeRaw(Map<String, int> map) async {
    await _prefs.setString(_storageKey, jsonEncode(map));
  }

  /// Returns valid (unexpired) dismissed trip IDs.
  Set<String> getDismissedTripIds() {
    final raw = _readRaw();
    final now = DateTime.now().millisecondsSinceEpoch;
    final validIds = <String>{};
    var hasExpired = false;

    for (final entry in raw.entries) {
      if (now - entry.value <= _expiryDurationMs) {
        validIds.add(entry.key);
      } else {
        hasExpired = true;
      }
    }

    // Lazy cleanup of expired dismissals
    if (hasExpired) {
      final cleaned = Map<String, int>.fromEntries(
        raw.entries.where((e) => now - e.value <= _expiryDurationMs),
      );
      _writeRaw(cleaned);
    }

    return validIds;
  }

  /// Records a trip as dismissed right now.
  Future<void> dismissTrip(String tripId) async {
    final raw = _readRaw();
    raw[tripId] = DateTime.now().millisecondsSinceEpoch;
    await _writeRaw(raw);
  }

  /// Removes a trip from the dismissed list (e.g. on Undo).
  Future<void> removeDismissedTrip(String tripId) async {
    final raw = _readRaw();
    if (raw.remove(tripId) != null) {
      await _writeRaw(raw);
    }
  }

  /// Clears all dismissed trips (e.g. "Reset skipped trips" in empty state).
  Future<void> clearAll() async {
    await _prefs.remove(_storageKey);
  }
}

final dismissedTripsStorageProvider = Provider<DismissedTripsStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DismissedTripsStorage(prefs);
});
