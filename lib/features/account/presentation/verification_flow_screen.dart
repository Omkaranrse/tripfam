import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/app_widgets.dart';
import '../data/verification_repository.dart';
import '../domain/verification_models.dart';

class VerificationFlowScreen extends ConsumerStatefulWidget {
  const VerificationFlowScreen({super.key});

  @override
  ConsumerState<VerificationFlowScreen> createState() =>
      _VerificationFlowScreenState();
}

class _VerificationFlowScreenState
    extends ConsumerState<VerificationFlowScreen> {
  final ImagePicker _picker = ImagePicker();
  late final VerificationInstruction _instruction;
  Uint8List? _capturedImageBytes;
  bool _isUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pick a random live instruction
    final random = Random();
    _instruction = VerificationInstruction
        .all[random.nextInt(VerificationInstruction.all.length)];
  }

  Future<void> _takeLiveSelfie() async {
    setState(() => _error = null);

    try {
      // Security: Strictly camera only (no gallery selection permitted)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = bytes;
        });
      }
    } catch (e) {
      setState(() {
        _error =
            'Unable to access front camera. Please check camera permissions.';
      });
    }
  }

  Future<void> _submitSelfie() async {
    if (_capturedImageBytes == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      await ref
          .read(verificationRepositoryProvider)
          .submitSelfie(
            _capturedImageBytes!,
            instructionCompleted: _instruction.title,
          );

      ref.invalidate(userVerificationStatusProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Selfie submitted for human review!'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Live Identity Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Instruction Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(120),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face_retouching_natural,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Live Pose Instruction',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _instruction.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _instruction.instruction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(180),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Camera / Preview Area
            Container(
              width: 280,
              height: 340,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _capturedImageBytes != null
                      ? Colors.green
                      : theme.colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _capturedImageBytes != null
                  ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.camera_front_rounded,
                            size: 64,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(
                              140,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Front Camera Only',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'No gallery uploads permitted',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(140),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Action Buttons
            if (_capturedImageBytes == null)
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Open Front Camera',
                  icon: Icons.camera_alt_rounded,
                  variant: AppButtonVariant.primary,
                  onPressed: _takeLiveSelfie,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Retake',
                      icon: Icons.refresh_rounded,
                      variant: AppButtonVariant.outlined,
                      onPressed: _isUploading ? null : _takeLiveSelfie,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Submit Selfie',
                      icon: Icons.cloud_upload_outlined,
                      isLoading: _isUploading,
                      variant: AppButtonVariant.primary,
                      onPressed: _submitSelfie,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // Honest Security Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verified by human review. A trained staff moderator compares your live selfie with your profile photo. Once reviewed, this photo is permanently deleted from storage.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
