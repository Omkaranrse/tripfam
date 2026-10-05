class TripFilter {
  const TripFilter({
    this.destinationQuery,
    this.startDate,
    this.endDate,
    this.minBudget,
    this.maxBudget,
    this.tags = const {},
  });

  final String? destinationQuery;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minBudget;
  final double? maxBudget;
  final Set<String> tags;

  bool get isActive =>
      (destinationQuery != null && destinationQuery!.trim().isNotEmpty) ||
      startDate != null ||
      endDate != null ||
      minBudget != null ||
      maxBudget != null ||
      tags.isNotEmpty;

  TripFilter copyWith({
    String? destinationQuery,
    DateTime? startDate,
    DateTime? endDate,
    double? minBudget,
    double? maxBudget,
    Set<String>? tags,
    bool clearDates = false,
    bool clearBudget = false,
  }) {
    return TripFilter(
      destinationQuery: destinationQuery ?? this.destinationQuery,
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
      minBudget: clearBudget ? null : (minBudget ?? this.minBudget),
      maxBudget: clearBudget ? null : (maxBudget ?? this.maxBudget),
      tags: tags ?? this.tags,
    );
  }
}
