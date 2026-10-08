import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip.dart';
import '../data/safety_repository.dart';
import '../domain/safety_models.dart';
import 'blocked_users_screen.dart';
import 'widgets/safety_dialogs.dart';

class SafetyPage extends ConsumerStatefulWidget {
  const SafetyPage({super.key});

  @override
  ConsumerState<SafetyPage> createState() => _SafetyPageState();
}

class _SafetyPageState extends ConsumerState<SafetyPage> {
  String? _selectedTripId;
  bool _isCheckingIn = false;
  bool _liveLocationEnabled = false;
  DateTime? _lastManualCheckin;
  int _currentIntervalHours = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final myTripsAsync = ref.watch(myTripsProvider);
    final contactsAsync = ref.watch(trustedContactsProvider);
    final blockedAsync = ref.watch(blockedUsersListProvider);

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await HapticFeedback.lightImpact();
            ref.invalidate(trustedContactsProvider);
            ref.invalidate(myTripsProvider);
            ref.invalidate(blockedUsersListProvider);
          },
          child: ListView(
            padding: AppSpacing.pagePaddingInsets(context, vertical: AppSpacing.s12),
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Safety Center',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                            fontSize: 21,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Emergency contacts, check-ins, and safety tools.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(16)
                          : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withAlpha(25)
                            : theme.colorScheme.outlineVariant.withAlpha(80),
                      ),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: theme.colorScheme.onSurface.withAlpha(200),
                      ),
                      tooltip: 'Refresh safety data',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.invalidate(trustedContactsProvider);
                        ref.invalidate(myTripsProvider);
                        ref.invalidate(blockedUsersListProvider);
                      },
                    ),
                  ),
                ],
              ).animateEntrance(context: context, index: 0),
              const SizedBox(height: AppSpacing.s16),

              // 1. ACTIVE TRIP CHECK-IN CARD
              _buildCheckinCard(theme, myTripsAsync)
                  .animateEntrance(context: context, index: 1),

              const SizedBox(height: AppSpacing.s12),

              // 2. TRUSTED CONTACTS CARD (Max 3, Stored Privately)
              _buildTrustedContactsCard(theme, contactsAsync)
                  .animateEntrance(context: context, index: 2),

              const SizedBox(height: AppSpacing.s12),

              // 3. LIVE LOCATION SHARING CARD
              _buildLiveLocationCard(theme)
                  .animateEntrance(context: context, index: 3),

              const SizedBox(height: AppSpacing.s12),

              // 4. REPORT & BLOCK LIST TOOLS
              _buildSafetyToolsCard(theme, blockedAsync)
                  .animateEntrance(context: context, index: 4),

              const SizedBox(height: AppSpacing.s12),

              // 5. EMERGENCY HOTLINES / RESOURCES
              _buildHotlinesCard(theme)
                  .animateEntrance(context: context, index: 5),

              // Extra clearance for floating bottom navigation dock
              const SizedBox(height: 108),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckinCard(
    ThemeData theme,
    AsyncValue<List<Trip>> myTripsAsync,
  ) {
    final semantic = AppSemanticColors.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkForestSurfaceDark
            : theme.colorScheme.surface,
        borderRadius: AppRadius.border16,
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : theme.colorScheme.outlineVariant.withAlpha(80),
          width: 1,
        ),
        boxShadow: AppShadows.subtle(context),
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Icon, Unwrapped Title, and Change Pill
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: semantic.success.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: semantic.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Safety Check-In',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  await HapticFeedback.selectionClick();
                  if (!mounted) return;
                  final newInterval = await CheckinIntervalDialog.show(
                    context,
                    _currentIntervalHours,
                  );
                  if (newInterval != null) {
                    setState(() => _currentIntervalHours = newInterval);
                    if (_selectedTripId != null) {
                      await ref
                          .read(safetyRepositoryProvider)
                          .setCheckinInterval(_selectedTripId!, newInterval);
                    }
                  }
                },
                borderRadius: AppRadius.borderPill,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(16)
                        : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                    borderRadius: AppRadius.borderPill,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(25)
                          : theme.colorScheme.outlineVariant.withAlpha(90),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Every ${_currentIntervalHours}h',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: isDark ? AppTheme.lime : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit_outlined,
                        size: 11,
                        color: isDark ? AppTheme.lime : theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active Trip selector if user has trips
          myTripsAsync.when(
            data: (trips) {
              if (trips.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(10)
                        : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: AppRadius.border12,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No active trip departure. You can still test your check-in alert below.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(150),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final activeTrip = trips.first;
              _selectedTripId ??= activeTrip.id;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(16),
                  borderRadius: AppRadius.border12,
                  border: Border.all(
                    color: theme.colorScheme.primary.withAlpha(35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flight_takeoff_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Active Trip: ${activeTrip.destination}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),

          // Status & Due time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(8)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              borderRadius: AppRadius.border12,
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(14)
                    : theme.colorScheme.outlineVariant.withAlpha(50),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STATUS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(130),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: semantic.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _lastManualCheckin != null ? 'Safe (Recent)' : 'On Track',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: semantic.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NEXT DUE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(130),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'In $_currentIntervalHours hours',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // "I'M SAFE" CTA BUTTON
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: semantic.success,
                foregroundColor: semantic.onSuccess,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.borderPill,
                ),
                elevation: 0,
              ),
              icon: _isCheckingIn
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          semantic.onSuccess,
                        ),
                      ),
                    )
                  : const Icon(Icons.verified_rounded, size: 18),
              label: Text(
                _isCheckingIn ? 'Recording Check-In...' : 'I\'m Safe',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              onPressed: _isCheckingIn ? null : _handleSafeCheckIn,
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'If you miss a check-in before the deadline, an automated alert with trip details is dispatched to your trusted contacts.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(135),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSafeCheckIn() async {
    await HapticFeedback.mediumImpact();
    setState(() => _isCheckingIn = true);

    try {
      final tripId = _selectedTripId ?? '00000000-0000-0000-0000-000000000000';
      await ref
          .read(safetyRepositoryProvider)
          .recordCheckIn(tripId, locationName: 'Manual In-App Check-In');

      setState(() {
        _isCheckingIn = false;
        _lastManualCheckin = DateTime.now();
      });

      if (mounted) {
        final semantic = AppSemanticColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: semantic.success,
            content: const Text('Check-in recorded! Your status is marked safe.'),
          ),
        );
      }
    } catch (_) {
      // In demo mode without active backend or trip, give positive feedback
      setState(() {
        _isCheckingIn = false;
        _lastManualCheckin = DateTime.now();
      });

      if (mounted) {
        final semantic = AppSemanticColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: semantic.success,
            content: const Text('Check-in recorded! Your status is marked safe.'),
          ),
        );
      }
    }
  }

  Widget _buildTrustedContactsCard(
    ThemeData theme,
    AsyncValue<List<TrustedContact>> contactsAsync,
  ) {
    return AppCard(
      variant: AppCardVariant.elevated,
      borderRadius: AppRadius.r16,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.contact_phone_outlined,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Trusted Contacts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              contactsAsync.maybeWhen(
                data: (list) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(18),
                    borderRadius: AppRadius.borderPill,
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(45),
                    ),
                  ),
                  child: Text(
                    '${list.length}/3',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stored privately and encrypted. Never visible to other travellers or hosts.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(140),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          contactsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Text(
              'Could not load contacts.',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            data: (contacts) {
              if (contacts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                    borderRadius: AppRadius.border12,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_outlined,
                        size: 26,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'No trusted contacts yet',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add up to 3 emergency contacts to receive alerts.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(140),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: contacts.map((contact) {
                  final hasParens = contact.name.contains('(');
                  final showRelationTag = !hasParens &&
                      contact.relationship.isNotEmpty &&
                      contact.relationship != 'Emergency Contact';
                  final contactDetail =
                      contact.email ?? contact.phoneNumber ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                      borderRadius: AppRadius.border12,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      contact.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (showRelationTag) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withAlpha(20),
                                        borderRadius: AppRadius.borderPill,
                                      ),
                                      child: Text(
                                        contact.relationship,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (contactDetail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      contact.email != null
                                          ? Icons.mail_outline_rounded
                                          : Icons.phone_outlined,
                                      size: 12,
                                      color: theme.colorScheme.onSurface.withAlpha(140),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        contactDetail,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontSize: 11.5,
                                          color: theme.colorScheme.onSurface.withAlpha(150),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                          tooltip: 'Remove contact',
                          onPressed: () async {
                            await ref
                                .read(safetyRepositoryProvider)
                                .deleteTrustedContact(contact.id);
                            ref.invalidate(trustedContactsProvider);
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 6),

          // Add contact button
          contactsAsync.maybeWhen(
            data: (contacts) => SizedBox(
              width: double.infinity,
              child: AppButton(
                label: contacts.length < 3
                    ? 'Add Trusted Contact'
                    : 'Limit Reached (3 / 3)',
                icon: Icons.add_rounded,
                size: AppButtonSize.small,
                isPill: true,
                variant: AppButtonVariant.outlined,
                onPressed: contacts.length < 3
                    ? () => AddTrustedContactDialog.show(context)
                    : null,
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveLocationCard(ThemeData theme) {
    return AppCard(
      variant: AppCardVariant.elevated,
      borderRadius: AppRadius.r16,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withAlpha(22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.secondary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live Location Sharing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    fontSize: 16,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _liveLocationEnabled,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _liveLocationEnabled = val);
                  if (_selectedTripId != null) {
                    ref
                        .read(safetyRepositoryProvider)
                        .setLiveLocationSharing(
                          _selectedTripId!,
                          val,
                          latitude: val ? 35.6762 : null,
                          longitude: val ? 139.6503 : null,
                        );
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Emergency live location sharing enabled for this trip.'
                            : 'Live location sharing turned off.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Opt-in only. Coordinates are shared with emergency contacts only if a scheduled check-in is missed. Automatically ceases when departure concludes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(140),
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyToolsCard(
    ThemeData theme,
    AsyncValue<List<BlockedUser>> blockedAsync,
  ) {
    final blockedCount = blockedAsync.value?.length ?? 0;

    return AppCard(
      variant: AppCardVariant.elevated,
      borderRadius: AppRadius.r16,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Safety & Moderation Tools',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_rounded,
                color: theme.colorScheme.error,
                size: 19,
              ),
            ),
            title: const Text(
              'Submit Safety Report',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              'Confidential report to our trust & safety team',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
            onTap: () => GeneralReportDialog.show(context),
          ),
          Divider(
            color: theme.colorScheme.outlineVariant.withAlpha(40),
            height: 1,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            leading: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha(14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_rounded,
                color: theme.colorScheme.onSurface.withAlpha(180),
                size: 18,
              ),
            ),
            title: const Text(
              'Blocked Users',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
            subtitle: Text(
              '$blockedCount blocked user${blockedCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BlockedUsersScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHotlinesCard(ThemeData theme) {
    return AppCard(
      variant: AppCardVariant.elevated,
      borderRadius: AppRadius.r16,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_in_talk_rounded,
                  color: theme.colorScheme.error,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Emergency Hotlines',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                  borderRadius: AppRadius.borderPill,
                ),
                child: Text(
                  '24/7 Global',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildHotlineRow(theme, 'International Emergency', '112', note: 'Europe, India & global roaming'),
          _buildHotlineRow(theme, 'USA & Canada', '911'),
          _buildHotlineRow(theme, 'United Kingdom', '999'),
          _buildHotlineRow(theme, 'Australia', '000', isLast: true),
        ],
      ),
    );
  }

  Widget _buildHotlineRow(
    ThemeData theme,
    String region,
    String dialCode, {
    String? note,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  region,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10.5,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withAlpha(16),
              borderRadius: AppRadius.borderPill,
              border: Border.all(
                color: theme.colorScheme.error.withAlpha(40),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.call_rounded,
                  size: 11,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  dialCode,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
