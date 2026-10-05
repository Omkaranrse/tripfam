import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_widgets.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip_filter.dart';

class TripFilterSheet extends ConsumerStatefulWidget {
  const TripFilterSheet({super.key});

  static const availableTags = [
    'Coastal Walks',
    'Foodie',
    'Culture',
    'Photography',
    'Backpacking',
    'Mountain Treks',
    'Temples',
    'Coffee',
    'Relaxed Pace',
  ];

  @override
  ConsumerState<TripFilterSheet> createState() => _TripFilterSheetState();
}

class _TripFilterSheetState extends ConsumerState<TripFilterSheet> {
  late Set<String> _selectedTags;
  double _minBudget = 0;
  double _maxBudget = 3000;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final current = ref.read(tripFilterProvider);
    _selectedTags = Set.from(current.tags);
    _minBudget = current.minBudget ?? 0;
    _maxBudget = current.maxBudget ?? 3000;
    _startDate = current.startDate;
    _endDate = current.endDate;
  }

  void _apply() {
    ref.read(tripFilterProvider.notifier).update((state) {
      return state.copyWith(
        minBudget: _minBudget > 0 ? _minBudget : null,
        maxBudget: _maxBudget < 3000 ? _maxBudget : null,
        startDate: _startDate,
        endDate: _endDate,
        tags: _selectedTags,
      );
    });
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _selectedTags.clear();
      _minBudget = 0;
      _maxBudget = 3000;
      _startDate = null;
      _endDate = null;
    });
    ref.read(tripFilterProvider.notifier).state = const TripFilter();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Trips',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
              const SizedBox(height: 20),

              // Date Range
              Text(
                'Departure Window',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                variant: AppCardVariant.outlined,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _startDate != null && _endDate != null
                          ? '${_startDate!.day}/${_startDate!.month} – ${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                          : 'Any upcoming date',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.date_range_outlined, size: 18),
                      label: Text(
                        _startDate == null ? 'Select Dates' : 'Change',
                      ),
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          initialDateRange:
                              _startDate != null && _endDate != null
                              ? DateTimeRange(
                                  start: _startDate!,
                                  end: _endDate!,
                                )
                              : null,
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked.start;
                            _endDate = picked.end;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Budget Range
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget Limit',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${_minBudget.round()} - \$${_maxBudget.round()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(_minBudget, _maxBudget),
                min: 0,
                max: 3000,
                divisions: 30,
                labels: RangeLabels(
                  '\$${_minBudget.round()}',
                  '\$${_maxBudget.round()}',
                ),
                onChanged: (vals) {
                  setState(() {
                    _minBudget = vals.start;
                    _maxBudget = vals.end;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Travel Vibe Tags
              Text(
                'Travel Vibe & Activities',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in TripFilterSheet.availableTags)
                    FilterChip(
                      label: Text(tag),
                      selected: _selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTags.add(tag);
                          } else {
                            _selectedTags.remove(tag);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 36),

              // Apply Button
              AppButton(
                label: 'Apply Filters',
                icon: Icons.check_rounded,
                isFullWidth: true,
                size: AppButtonSize.large,
                onPressed: _apply,
              ),
            ],
          ),
        );
      },
    );
  }
}
