import 'trip.dart';

class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.userId,
    required this.tripId,
    required this.createdAt,
    this.trip,
  });

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    return SavedTrip(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tripId: json['trip_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      trip: json['trip'] != null ? Trip.fromJson(json['trip'] as Map<String, dynamic>) : null,
    );
  }

  final String id;
  final String userId;
  final String tripId;
  final DateTime createdAt;
  final Trip? trip;
}
