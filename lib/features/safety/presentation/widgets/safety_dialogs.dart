import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/safety_repository.dart';

class AddTrustedContactDialog extends ConsumerStatefulWidget {
  const AddTrustedContactDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const AddTrustedContactDialog(),
    );
  }

  @override
  ConsumerState<AddTrustedContactDialog> createState() =>
      _AddTrustedContactDialogState();
}

class _AddTrustedContactDialogState
    extends ConsumerState<AddTrustedContactDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _relationship = 'Family';
  bool _isSubmitting = false;
  String? _error;

  static const _relationships = [
    'Family',
    'Parent',
    'Partner / Spouse',
    'Sibling',
    'Close Friend',
    'Colleague',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.length < 2) {
      setState(
        () => _error = 'Please enter a valid name (at least 2 letters).',
      );
      return;
    }

    if (phone.isEmpty && email.isEmpty) {
      setState(
        () => _error =
            'Please provide either a phone number or an email address.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(safetyRepositoryProvider)
          .addTrustedContact(
            name: name,
            phone: phone.isNotEmpty ? phone : null,
            email: email.isNotEmpty ? email : null,
            relationship: _relationship,
          );

      ref.invalidate(trustedContactsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.shield_outlined,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Add Trusted Contact'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your trusted contact will receive emergency notifications if you miss a scheduled safety check-in.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'e.g. Maya Sharma',
            ),
            const SizedBox(height: 12),
            Text(
              'Relationship',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _relationships.map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _relationship = val);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phoneController,
              label: 'Phone Number (Optional)',
              hint: '+1 555 123 4567',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _emailController,
              label: 'Email Address (Optional)',
              hint: 'contact@example.com',
              keyboardType: TextInputType.emailAddress,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Save Contact',
          isLoading: _isSubmitting,
          variant: AppButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class CheckinIntervalDialog extends StatefulWidget {
  const CheckinIntervalDialog({
    required this.currentInterval,
    required this.onIntervalSelected,
    super.key,
  });

  final int currentInterval;
  final ValueChanged<int> onIntervalSelected;

  static Future<int?> show(BuildContext context, int currentInterval) {
    return showDialog<int>(
      context: context,
      builder: (context) => CheckinIntervalDialog(
        currentInterval: currentInterval,
        onIntervalSelected: (interval) => Navigator.of(context).pop(interval),
      ),
    );
  }

  @override
  State<CheckinIntervalDialog> createState() => _CheckinIntervalDialogState();
}

class _CheckinIntervalDialogState extends State<CheckinIntervalDialog> {
  late int _selected;

  static const _options = [
    (4, 'Every 4 hours', 'High alert: remote trails or solo exploring'),
    (6, 'Every 6 hours', 'Active daytime adventures'),
    (12, 'Every 12 hours (Recommended)', 'Twice daily (morning and evening)'),
    (24, 'Every 24 hours', 'Daily peace of mind check-in'),
    (48, 'Every 48 hours', 'Relaxed multi-day check-in'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentInterval;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Set Check-In Interval'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options.map((opt) {
            final isSelected = opt.$1 == _selected;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? theme.colorScheme.primary : null,
              ),
              title: Text(
                opt.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(opt.$3, style: theme.textTheme.bodySmall),
              selected: isSelected,
              onTap: () => setState(() => _selected = opt.$1),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => widget.onIntervalSelected(_selected),
          child: const Text('Save Interval'),
        ),
      ],
    );
  }
}

class GeneralReportDialog extends ConsumerStatefulWidget {
  const GeneralReportDialog({
    this.reportedUserId,
    this.reportedUserName,
    this.tripId,
    super.key,
  });

  final String? reportedUserId;
  final String? reportedUserName;
  final String? tripId;

  static Future<bool?> show(
    BuildContext context, {
    String? reportedUserId,
    String? reportedUserName,
    String? tripId,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => GeneralReportDialog(
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        tripId: tripId,
      ),
    );
  }

  @override
  ConsumerState<GeneralReportDialog> createState() =>
      _GeneralReportDialogState();
}

class _GeneralReportDialogState extends ConsumerState<GeneralReportDialog> {
  final _detailsController = TextEditingController();
  String _selectedReason = 'Safety concern';
  bool _isSubmitting = false;
  String? _error;

  static const _reasons = [
    'Safety concern',
    'Harassment or threatening behavior',
    'Inappropriate or offensive content',
    'Financial fraud or scam',
    'Unverified or impersonated identity',
    'Other violation',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      setState(() => _error = 'Please provide details for the safety team.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref
          .read(safetyRepositoryProvider)
          .submitReport(
            reason: _selectedReason,
            details: details,
            reportedUserId: widget.reportedUserId,
            tripId: widget.tripId,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.report_problem_rounded,
            color: theme.colorScheme.error,
            size: 24,
          ),
          const SizedBox(width: 8),
          const Text('Submit Safety Report'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your report is strictly confidential and reviewed by our trust & safety team within 24 hours.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _detailsController,
              label: 'Details',
              hint:
                  'Describe what happened with as much context as possible...',
              maxLines: 4,
              maxLength: 2000,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        AppButton(
          label: 'Submit Report',
          isLoading: _isSubmitting,
          variant: AppButtonVariant.primary,
          onPressed: _submit,
        ),
      ],
    );
  }
}
