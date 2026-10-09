import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String? _signedAvatarUrl;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = Theme.of(context);
    final semantic = AppSemanticColors.of(context);

    return Scaffold(
      body: profileAsync.when(
        data: (profile) {
          if (profile != null &&
              profile.avatarPath != null &&
              profile.avatarPath!.isNotEmpty &&
              _signedAvatarUrl == null) {
            ref
                .read(profileRepositoryProvider)
                .getAvatarSignedUrl(profile.avatarPath!)
                .then((url) {
                  if (mounted && url != null) {
                    setState(() => _signedAvatarUrl = url);
                  }
                });
          }

          final displayName = profile?.displayName.isNotEmpty == true
              ? profile!.displayName
              : 'Solo Explorer';
          final isVerified = profile?.isVerified ?? false;
          final homeCity = profile?.homeCity ?? 'City not set';
          final bio = profile?.bio ?? 'No bio added yet.';
          final travelStyle = profile?.travelStyle ?? {};

          // Filter out internal stats/metadata from genuine travel style preferences
          final styleChips = travelStyle.entries.where((e) {
            final key = e.key.toLowerCase();
            if (key == 'trips_completed' ||
                key == 'trips_hosted' ||
                key == 'safety_status') {
              return false;
            }
            if (e.value is num) return false;
            return true;
          }).toList();

          return ListView(
            padding: AppSpacing.pagePaddingInsets(context, vertical: 12),
            children: [
              // Header Section with in-line Edit action
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
                          'Profile & Settings',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4,
                            fontSize: 21,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Manage your traveller identity and account preferences.',
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
                  AppButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    variant: AppButtonVariant.outlined,
                    size: AppButtonSize.small,
                    isPill: true,
                    onPressed: () => context.push('/profile/edit'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // 1. User Info Card
              AppCard(
                variant: AppCardVariant.elevated,
                borderRadius: AppRadius.r16,
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.primary.withAlpha(25),
                          backgroundImage: _signedAvatarUrl != null
                              ? NetworkImage(_signedAvatarUrl!)
                              : null,
                          child: _signedAvatarUrl == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 36,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _VerifiedBadge(isVerified: isVerified),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: theme.colorScheme.onSurface.withAlpha(140),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      homeCity,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface.withAlpha(160),
                                        fontSize: 12.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: theme.colorScheme.outlineVariant.withAlpha(50), height: 1),
                    const SizedBox(height: 10),
                    Text(
                      'About Me',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bio,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(170),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // 2. Identity Verification Card
              AppCard(
                variant: AppCardVariant.elevated,
                borderRadius: AppRadius.r16,
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isVerified
                            ? semantic.success.withAlpha(25)
                            : theme.colorScheme.primaryContainer.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isVerified
                            ? Icons.verified_rounded
                            : Icons.shield_outlined,
                        color: isVerified
                            ? semantic.success
                            : theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVerified
                                ? 'Verified by review'
                                : 'Identity Verification',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isVerified
                                ? 'Your identity is confirmed by our moderation team.'
                                : 'Complete a quick live selfie check to get verified.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: isVerified ? 'View' : 'Verify',
                      variant: AppButtonVariant.outlined,
                      size: AppButtonSize.small,
                      isPill: true,
                      onPressed: () => context.push('/verification'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Staff review dashboard access for staff/admin users
              if (profile?.role == 'staff' || profile?.role == 'admin') ...[
                AppCard(
                  variant: AppCardVariant.elevated,
                  borderRadius: AppRadius.r16,
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        color: Colors.purple,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Staff Review Queue',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Review pending identity verification requests.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/admin/verification'),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              // 3. Travel Style Card (Clean Preferences without raw stats)
              if (styleChips.isNotEmpty)
                AppCard(
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
                              color: theme.colorScheme.primary.withAlpha(20),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.explore_outlined,
                              color: theme.colorScheme.primary,
                              size: 17,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Travel Style',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in styleChips)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(16),
                                borderRadius: AppRadius.borderPill,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha(45),
                                ),
                              ),
                              child: Text(
                                entry.value.toString(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              if (styleChips.isNotEmpty) const SizedBox(height: AppSpacing.s12),

              // 4. Privacy & Legal Card
              AppCard(
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
                            color: theme.colorScheme.primary.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.privacy_tip_outlined,
                            size: 17,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Privacy & Safety',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.download_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                      title: const Text(
                        'Export my data',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        'Download a machine-readable JSON copy of your records',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: theme.colorScheme.onSurface.withAlpha(140),
                        ),
                      ),
                      trailing: _isExporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurface.withAlpha(120),
                            ),
                      onTap: _isExporting ? null : _handleExportData,
                    ),
                    Divider(
                      color: theme.colorScheme.outlineVariant.withAlpha(40),
                      height: 1,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.policy_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                      title: const Text(
                        'Privacy Policy',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                      onTap: () => context.push('/privacy-policy'),
                    ),
                    Divider(
                      color: theme.colorScheme.outlineVariant.withAlpha(40),
                      height: 1,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                      title: const Text(
                        'Terms of Service',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                      onTap: () => context.push('/terms'),
                    ),
                    Divider(
                      color: theme.colorScheme.outlineVariant.withAlpha(40),
                      height: 1,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      leading: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                      title: const Text(
                        'Community Safety Guide',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurface.withAlpha(120),
                      ),
                      onTap: () => context.push('/safety-guide'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // 5. Actions: Sign Out & Delete Account
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Sign Out',
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.medium,
                  isPill: true,
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 17,
                  ),
                  label: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => _confirmDeleteAccount(context),
                ),
              ),

              // Extra clearance for floating bottom navigation dock
              const SizedBox(height: 108),
            ],
          );
        },
        loading: () => const _ProfileLoadingSkeleton(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.read(userProfileProvider.notifier).refresh(),
        ),
      ),
    );
  }


  Future<void> _handleExportData() async {
    setState(() => _isExporting = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final data = await repo.exportUserData();
      if (!mounted) return;

      final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
      final semantic = AppSemanticColors.of(context);

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.download_done_rounded, color: semantic.success),
              const SizedBox(width: 8),
              const Text('Your Data Export'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Here is a complete JSON copy of your profile, trips, messages, check-ins, and trusted contacts.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        prettyJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: prettyJson));
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Data export copied to clipboard.'),
                  ),
                );
              },
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSafeSnackBar(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This action is irreversible. All your profile data, trips, uploaded avatars, and messages will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(profileRepositoryProvider).deleteAccount();
                if (context.mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  AppErrorHandler.showSafeSnackBar(context, e);
                }
              }
            },
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isVerified) {
      return Tooltip(
        message: 'Identity Verified Solo Traveller',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.fromBorderSide(
              BorderSide(color: theme.colorScheme.primary.withAlpha(60)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Verified',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Unverified: Submit verification in Safety',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Unverified',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadingSkeleton extends StatelessWidget {
  const _ProfileLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainer;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      children: [
        // Header row skeleton
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 180,
                  height: 24,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Container(
                  width: 260,
                  height: 14,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s24),

        // User info card skeleton
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 36, backgroundColor: placeholderColor),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 18,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Container(
                          width: 100,
                          height: 14,
                          decoration: BoxDecoration(
                            color: placeholderColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Verification card skeleton
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: placeholderColor),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 16,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Container(
                      width: 220,
                      height: 12,
                      decoration: BoxDecoration(
                        color: placeholderColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Settings card skeleton
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(AppRadius.r12),
            ),
          ),
        ),
      ],
    );
  }
}
