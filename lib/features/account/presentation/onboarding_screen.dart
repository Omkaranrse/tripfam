import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_error_handler.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();

  Uint8List? _avatarBytes;
  String? _avatarExt;
  bool _isLoading = false;

  // Travel style questionnaire answers
  String _wakeUpTime = 'Balanced (8-10 AM)';
  String _budgetLevel = 'Balanced (\$\$)';
  String _travelPace = 'Moderate (2-3 spots/day)';
  String _planningStyle = 'Semi-planned (key anchors only)';

  @override
  void initState() {
    super.initState();
    // Prefill name if profile already exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        if (profile.displayName.isNotEmpty) {
          _nameController.text = profile.displayName;
        }
        if (profile.homeCity != null) {
          _cityController.text = profile.homeCity!;
        }
        if (profile.bio != null) {
          _bioController.text = profile.bio!;
        }
      }
    });
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
        imageQuality: 85, // Compression
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

  Future<void> _handleCompleteOnboarding() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppErrorHandler.showSafeSnackBar(
        context,
        null,
        fallbackMessage: 'Session expired. Please sign in again.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? avatarPath;
      if (_avatarBytes != null && _avatarExt != null) {
        avatarPath = await ref
            .read(profileRepositoryProvider)
            .uploadAvatar(bytes: _avatarBytes!, fileExtension: _avatarExt!);
      }

      final profile = UserProfile(
        id: user.id,
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

      await ref.read(userProfileProvider.notifier).updateProfile(profile);

      if (mounted) {
        context.go('/discover');
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
        title: const Text('Traveller Onboarding'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tell us about yourself',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This helps compatible solo travellers connect with you before trips.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Avatar Picker
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: theme.colorScheme.primary
                                .withAlpha(25),
                            backgroundImage: _avatarBytes != null
                                ? MemoryImage(_avatarBytes!)
                                : null,
                            child: _avatarBytes == null
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
                    const SizedBox(height: 28),

                    // Name
                    AppTextField(
                      controller: _nameController,
                      label: 'Display Name * (2 - 60 chars)',
                      hint: 'e.g. Maya Chen',
                      prefixIcon: Icons.badge_outlined,
                      validator: (val) {
                        final trimmed = val?.trim() ?? '';
                        if (trimmed.length < 2) {
                          return 'Display name must be at least 2 characters.';
                        }
                        if (trimmed.length > 60) {
                          return 'Display name cannot exceed 60 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Home City
                    AppTextField(
                      controller: _cityController,
                      label: 'Home City *',
                      hint: 'e.g. Barcelona, Spain',
                      prefixIcon: Icons.location_city_outlined,
                      validator: (val) {
                        final trimmed = val?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Please enter your home city.';
                        }
                        if (trimmed.length > 100) {
                          return 'Home city cannot exceed 100 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    AppTextField(
                      controller: _bioController,
                      label: 'Short Bio (optional)',
                      hint: 'Tell fellow travellers what you love about solo exploring...',
                      maxLines: 3,
                      validator: (val) {
                        final trimmed = val?.trim() ?? '';
                        if (trimmed.length > 1000) {
                          return 'Bio cannot exceed 1000 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // Travel Style Questionnaire
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

                    // Submit Button
                    AppButton(
                      label: 'Complete Profile & Start Exploring',
                      icon: Icons.check_circle_outline_rounded,
                      isLoading: _isLoading,
                      isFullWidth: true,
                      size: AppButtonSize.large,
                      onPressed: _handleCompleteOnboarding,
                    ),
                  ],
                ),
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
