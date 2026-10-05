class TripPreview {
  const TripPreview({
    required this.destination,
    required this.title,
    required this.summary,
    required this.departureDate,
    required this.durationDays,
    required this.travellerCount,
    required this.availablePlaces,
  });

  final String destination;
  final String title;
  final String summary;
  final DateTime departureDate;
  final int durationDays;
  final int travellerCount;
  final int availablePlaces;
}
