import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/trip_repository.dart';
import '../domain/trip.dart';

class TripFormScreen extends ConsumerStatefulWidget {
  const TripFormScreen({this.initialTrip, super.key});

  final Trip? initialTrip;

  @override
  ConsumerState<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends ConsumerState<TripFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destinationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(days: 14));
  DateTime _endDate = DateTime.now().add(const Duration(days: 21));
  int _maxMembers = 4;
  final Set<String> _selectedTags = {'Foodie', 'Culture'};
  bool _requiresVerifiedMembers = false;
  bool _isLoading = false;

  static const _availableVibeTags = [
    'Foodie',
    'Culture',
    'Photography',
    'Coastal Walks',
    'Backpacking',
    'Mountain Treks',
    'Temples',
    'Coffee',
    'Relaxed Pace',
    'Nightlife',
  ];

  bool get _isEditing => widget.initialTrip != null;
  bool get _isLockedForMembers =>
      _isEditing && widget.initialTrip!.hasConfirmedMembers;

  @override
  void initState() {
    super.initState();
    final trip = widget.initialTrip;
    if (trip != null) {
      _destinationController.text = trip.destination;
      _budgetController.text = trip.budget != null
          ? trip.budget!.round().toString()
          : '';
      _descriptionController.text = trip.description;
      _startDate = trip.startDate;
      _endDate = trip.endDate;
      _maxMembers = trip.maxMembers;
      _requiresVerifiedMembers = trip.requiresVerifiedMembers;
      _selectedTags.clear();
      _selectedTags.addAll(trip.tags);
    }
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _budgetController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final draft = TripDraft(
      destination: _destinationController.text.trim(),
      startDate: _startDate,
      endDate: _endDate,
      budget: double.tryParse(_budgetController.text.trim()),
      maxMembers: _maxMembers,
      description: _descriptionController.text.trim(),
      tags: _selectedTags.toList(),
      requiresVerifiedMembers: _requiresVerifiedMembers,
    );

    final validationError = draft.validate();
    if (validationError != null) {
      AppErrorHandler.showSafeSnackBar(
        context,
        null,
        fallbackMessage: validationError,
      );
      return;
    }

    setState(() => _isLoading = true);
    final repo = ref.read(tripRepositoryProvider);

    try {
      if (_isEditing) {
        await repo.updateTrip(widget.initialTrip!.id, draft);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip updated successfully.')),
          );
          context.pop();
        }
      } else {
        final created = await repo.createTrip(draft);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your trip is now live on Discover!')),
          );
          context.go('/trip/${created.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSafeSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Trip' : 'Host an Adventure'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLockedForMembers) ...[
                    AppCard(
                      variant: AppCardVariant.flat,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Destination and dates are locked because travellers have already joined this departure.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(
                                  180,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Destination
                  AppTextField(
                    controller: _destinationController,
                    label: 'Destination * (2 - 150 chars)',
                    hint: 'e.g. Kyoto, Japan or Amalfi Coast, Italy',
                    enabled: !_isLockedForMembers,
                    prefixIcon: Icons.location_on_outlined,
                    validator: (val) {
                      final clean = val?.trim() ?? '';
                      if (clean.length < 2) {
                        return 'Min 2 characters required.';
                      }
                      if (clean.length > 150) {
                        return 'Max 150 characters allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),

                  // Dates
                  Text(
                    'Trip Dates *',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                          '${_startDate.day}/${_startDate.month}/${_startDate.year} – ${_endDate.day}/${_endDate.month}/${_endDate.year} (${_endDate.difference(_startDate).inDays + 1} days)',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (!_isLockedForMembers)
                          TextButton(
                            child: const Text('Change'),
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 730),
                                ),
                                initialDateRange: DateTimeRange(
                                  start: _startDate,
                                  end: _endDate,
                                ),
                              );
                              if (range != null) {
                                setState(() {
                                  _startDate = range.start;
                                  _endDate = range.end;
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Budget & Max Members Row
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _budgetController,
                          label: 'Estimated Budget (\$ USD)',
                          hint: 'e.g. 1200',
                          prefixIcon: Icons.attach_money_rounded,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return null;
                            final parsed = double.tryParse(val.trim());
                            if (parsed == null || parsed < 0) {
                              return 'Enter valid positive number.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Max Travellers (2 - 12)',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: _maxMembers > 2
                                        ? () => setState(() => _maxMembers--)
                                        : null,
                                  ),
                                  Text(
                                    '$_maxMembers',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: _maxMembers < 12
                                        ? () => setState(() => _maxMembers++)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Vibe Tags
                  Text(
                    'Trip Vibe Tags',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _availableVibeTags)
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
                  const SizedBox(height: 18),

                  // Description
                  AppTextField(
                    controller: _descriptionController,
                    label: 'Description * (10 - 5000 chars)',
                    hint: 'Outline the itinerary, highlights, vibe, and what kind of travel companions you are seeking...',
                    maxLines: 5,
                    validator: (val) {
                      final clean = val?.trim() ?? '';
                      if (clean.length < 10) {
                        return 'Min 10 characters required.';
                      }
                      if (clean.length > 5000) {
                        return 'Max 5000 characters allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Verified-Only Gating
                  AppCard(
                    variant: AppCardVariant.outlined,
                    padding: const EdgeInsets.all(12),
                    child: SwitchListTile(
                      value: _requiresVerifiedMembers,
                      onChanged: (val) =>
                          setState(() => _requiresVerifiedMembers = val),
                      title: Text(
                        'Verified Travellers Only',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Only members who completed manual photo review can request to join.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(160),
                        ),
                      ),
                      secondary: Icon(
                        Icons.verified_user_outlined,
                        color: _requiresVerifiedMembers
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withAlpha(120),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit
                  AppButton(
                    label: _isEditing ? 'Save Changes' : 'Publish Trip',
                    icon: _isEditing
                        ? Icons.save_outlined
                        : Icons.publish_rounded,
                    isLoading: _isLoading,
                    isFullWidth: true,
                    size: AppButtonSize.large,
                    onPressed: _handleSubmit,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
