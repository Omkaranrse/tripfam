import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/meeting_link_validator.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/join_request_repository.dart';
import '../../domain/join_request.dart';

class IntroCallDialog extends ConsumerStatefulWidget {
  const IntroCallDialog({
    required this.introCall,
    required this.tripId,
    super.key,
  });

  final IntroCall introCall;
  final String tripId;

  static Future<bool?> show(
    BuildContext context, {
    required IntroCall introCall,
    required String tripId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          IntroCallDialog(introCall: introCall, tripId: tripId),
    );
  }

  @override
  ConsumerState<IntroCallDialog> createState() => _IntroCallDialogState();
}

class _IntroCallDialogState extends ConsumerState<IntroCallDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _linkController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController(
      text: widget.introCall.meetingLink ?? '',
    );
    if (widget.introCall.scheduledAt != null) {
      _selectedDate = widget.introCall.scheduledAt;
      _selectedTime = TimeOfDay.fromDateTime(widget.introCall.scheduledAt!);
    } else {
      _selectedDate = DateTime.now().add(const Duration(days: 1));
      _selectedTime = const TimeOfDay(hour: 18, minute: 0);
    }
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  DateTime? _combineDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final combined = _combineDateTime();
    if (combined == null || combined.isBefore(DateTime.now())) {
      setState(() {
        _errorMessage =
            'Please choose a future date and time for the intro call.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(joinRequestRepositoryProvider)
          .scheduleIntroCall(
            widget.introCall.id,
            scheduledAt: combined,
            meetingLink: _linkController.text.trim(),
          );

      // Refresh providers
      ref.invalidate(tripJoinRequestsProvider(widget.tripId));
      ref.invalidate(userTripRequestProvider(widget.tripId));
      ref.invalidate(myJoinRequestsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Intro call scheduled successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkText = _linkController.text.trim();
    final serviceType = MeetingLinkValidator.getServiceType(linkText);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Schedule Intro Call',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinate a 15-minute video intro before travelling together. Both sides must confirm after the call to unlock the group chat.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              ),
              const SizedBox(height: 20),

              // Date & Time Picker Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      label: Text(
                        _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Pick Date',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 18),
                      label: Text(
                        _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Pick Time',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Meeting link input
              AppTextField(
                controller: _linkController,
                label: 'Meeting Link',
                hint: 'https://meet.google.com/abc-defg-hij',
                prefixIcon: Icons.link_rounded,
                onChanged: (_) => setState(() {}),
                validator: MeetingLinkValidator.validate,
              ),

              // Provider detection badge
              if (linkText.isNotEmpty &&
                  MeetingLinkValidator.isValid(linkText)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Recognized provider: $serviceType (HTTPS verified)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  'Accepts only secure HTTPS links from Google Meet, Zoom, or WhatsApp.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(140),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: widget.introCall.isScheduled
                      ? 'Update Call Details'
                      : 'Propose Intro Call',
                  icon: Icons.video_call_rounded,
                  isLoading: _isLoading,
                  onPressed: _submit,
                  variant: AppButtonVariant.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
