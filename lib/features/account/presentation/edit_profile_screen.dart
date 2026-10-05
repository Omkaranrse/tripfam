import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  Uint8List? _avatarBytes;
  String? _avatarExt;
  String? _currentSignedAvatarUrl;
  bool _isLoading = false;

  String _wakeUpTime = 'Balanced (8-10 AM)';
  String _budgetLevel = 'Balanced (\$\$)';
  String _travelPace = 'Moderate (2-3 spots/day)';
  String _planningStyle = 'Semi-planned (key anchors only)';

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _cityController.text = profile.homeCity ?? '';
      _bioController.text = profile.bio ?? '';

      final style = profile.travelStyle;
      _wakeUpTime = (style['wake_up_time'] as String?) ?? _wakeUpTime;
      _budgetLevel = (style['budget_level'] as String?) ?? _budgetLevel;
      _travelPace = (style['pace'] as String?) ?? _travelPace;
      _planningStyle = (style['planning_style'] as String?) ?? _planningStyle;

      if (profile.avatarPath != null && profile.avatarPath!.isNotEmpty) {
        ref
            .read(profileRepositoryProvider)
            .getAvatarSignedUrl(profile.avatarPath!)
            .then((url) {
              if (mounted && url != null) {
                setState(() => _currentSignedAvatarUrl = url);
              }
            });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.split('.').last.toLowerCase();

        const allowedExts = {'jpg', 'jpeg', 'png', 'webp'};
        if (!allowedExts.contains(ext)) {
          if (mounted) {
            AppErrorHandler.showSafeSnackBar(
              context,
              null,
              fallbackMessage: 'Only JPG, PNG, and WebP images are supported.',
            );
          }
          return;
        }

        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) {
            AppErrorHandler.showSafeSnackBar(
              context,
              null,
              fallbackMessage: 'Image exceeds 5MB size limit.',
            );
          }
          return;
        }

        setState(() {
          _avatarBytes = bytes;
          _avatarExt = ext;
        });
      }
    } catch (e) {
      if (mounted) {
        AppErrorHandler.showSafeSnackBar(context, e);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = ref.read(userProfileProvider).value;
    if (existing == null) return;

    setState(() => _isLoading = true);

    try {
      String? avatarPath = existing.avatarPath;
      if (_avatarBytes != null && _avatarExt != null) {
        avatarPath = await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(bytes: _avatarBytes!, fileExtension: _avatarExt!);
      }

      final updated = existing.copyWith(
        displayName: _nameController.text.trim(),
        homeCity: _cityController.text.trim(),
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        avatarPath: avatarPath,
        travelStyle: {
          'wake_up_time': _wakeUpTime,
          'budget_level': _budgetLevel,
          'pace': _travelPace,
          'planning_style': _planningStyle,
        },
      );

      await ref.read(userProfileProvider.notifier).updateProfile(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
        context.pop();
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
    final profile = ref.watch(userProfileProvider).value;
    final isVerified = profile?.isVerified ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppButton(
              label: 'Save',
              isLoading: _isLoading,
              size: AppButtonSize.small,
              onPressed: _handleSave,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Verification Notice
                  AppCard(
                    variant: AppCardVariant.flat,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          isVerified
                              ? Icons.verified_rounded
                              : Icons.gpp_maybe_rounded,
                          color: isVerified
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVerified
                                    ? 'Identity Verified Traveller'
                                    : 'Unverified Traveller',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isVerified
                                    ? 'Your identity was verified through government ID and selfie checks.'
                                    : 'Verification can be requested in the Safety tab.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    160,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: theme.colorScheme.primary.withAlpha(
                            25,
                          ),
                          backgroundImage: _avatarBytes != null
                              ? MemoryImage(_avatarBytes!)
                              : (_currentSignedAvatarUrl != null
                                        ? NetworkImage(_currentSignedAvatarUrl!)
                                        : null)
                                    as ImageProvider?,
                          child:
                              _avatarBytes == null &&
                                  _currentSignedAvatarUrl == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: theme.colorScheme.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Material(
                            color: theme.colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 2,
                            child: InkWell(
                              onTap: _pickAvatar,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AppTextField(
                    controller: _nameController,
                    label: 'Display Name * (2 - 60 chars)',
                    hint: 'Your display name',
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.length < 2) {
                        return 'Min 2 characters required.';
                      }
                      if (trimmed.length > 60) {
                        return 'Max 60 characters allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _cityController,
                    label: 'Home City *',
                    hint: 'e.g. Kyoto, Japan',
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.isEmpty) {
                        return 'Please enter your home city.';
                      }
                      if (trimmed.length > 100) {
                        return 'Max 100 characters allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _bioController,
                    label: 'Short Bio (optional)',
                    hint: 'Your travel style and interests...',
                    maxLines: 3,
                    validator: (val) {
                      final trimmed = val?.trim() ?? '';
                      if (trimmed.length > 1000) {
                        return 'Max 1000 characters allowed.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'Travel Style Questionnaire',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _QuestionnaireSection(
                    title: '🌅 Morning Rhythm',
                    selected: _wakeUpTime,
                    options: const [
                      'Early Bird (6-8 AM)',
                      'Balanced (8-10 AM)',
                      'Night Owl (10 AM+)',
                    ],
                    onSelected: (val) => setState(() => _wakeUpTime = val),
                  ),
                  const SizedBox(height: 16),

                  _QuestionnaireSection(
                    title: '💰 Budget Level',
                    selected: _budgetLevel,
                    options: const [
                      'Backpacker (\$)',
                      'Balanced (\$\$)',
                      'Luxury / Splurge (\$\$\$)',
                    ],
                    onSelected: (val) => setState(() => _budgetLevel = val),
                  ),
                  const SizedBox(height: 16),

                  _QuestionnaireSection(
                    title: '🏃 Daily Pace',
                    selected: _travelPace,
                    options: const [
                      'Relaxed (1-2 spots/day)',
                      'Moderate (2-3 spots/day)',
                      'Action-Packed (all day)',
                    ],
                    onSelected: (val) => setState(() => _travelPace = val),
                  ),
                  const SizedBox(height: 16),

                  _QuestionnaireSection(
                    title: '🗺️ Planning Style',
                    selected: _planningStyle,
                    options: const [
                      'Spontaneous (go with flow)',
                      'Semi-planned (key anchors only)',
                      'Structured (detailed itinerary)',
                    ],
                    onSelected: (val) => setState(() => _planningStyle = val),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionnaireSection extends StatelessWidget {
  const _QuestionnaireSection({
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option),
                selected: selected == option,
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}
