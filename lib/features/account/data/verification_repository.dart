import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../domain/verification_models.dart';

abstract interface class VerificationRepository {
  Future<UserVerificationState> getVerificationStatus();

  Future<void> submitSelfie(
    Uint8List imageBytes, {
    required String instructionCompleted,
  });

  Future<List<AdminVerificationItem>> getAdminQueue();

  Future<void> approveRequest(String requestId, {String? notes});

  Future<void> rejectRequest(String requestId, {required String reason});

  Future<String?> getSignedSelfieUrl(String storagePath);
}

class SupabaseVerificationRepository implements VerificationRepository {
  SupabaseVerificationRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<UserVerificationState> getVerificationStatus() async {
    if (_client == null || DemoData.enabled) {
      return const UserVerificationState(
        status: VerificationStatus.verified,
        isVerified: true,
        requestId: 'req-verif-omkar',
        instructionCompleted: 'Smile and look straight',
      );
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      return const UserVerificationState(
        status: VerificationStatus.notSubmitted,
        isVerified: false,
      );
    }

    try {
      final response = await _client.rpc<dynamic>(
        'get_user_verification_status',
      );
      if (response != null && response is Map<String, dynamic>) {
        return UserVerificationState.fromJson(response);
      }
    } catch (_) {}

    return const UserVerificationState(
      status: VerificationStatus.notSubmitted,
      isVerified: false,
    );
  }

  @override
  Future<void> submitSelfie(
    Uint8List imageBytes, {
    required String instructionCompleted,
  }) async {
    if (_client == null) {
      throw Exception('Authentication required for identity verification.');
    }

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not signed in.');

    final fileName = 'selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storagePath = '${user.id}/$fileName';

    try {
      // 1. Upload to private verification-selfies bucket
      await _client.storage
          .from('verification-selfies')
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // 2. Submit verification request record via RPC
      await _client.rpc<dynamic>(
        'submit_verification_request',
        params: {
          'p_selfie_storage_path': storagePath,
          'p_instruction_completed': instructionCompleted,
        },
      );
    } catch (e) {
      final err = e.toString();
      if (err.contains('already verified')) {
        throw Exception('Your profile is already verified.');
      }
      if (err.contains('already have a verification request')) {
        throw Exception(
          'You already have a verification request pending review.',
        );
      }
      throw Exception(
        'Failed to submit verification selfie: ${TextSanitizer.sanitize(err)}',
      );
    }
  }

  @override
  Future<List<AdminVerificationItem>> getAdminQueue() async {
    if (_client == null || DemoData.enabled) {
      return [
        AdminVerificationItem(
          requestId: 'req-verif-kabir',
          userId: DemoUsers.kabir.id,
          displayName: DemoUsers.kabir.displayName,
          selfieStoragePath: 'selfies/kabir.jpg',
          avatarPath: DemoUsers.kabir.avatarPath,
          instructionCompleted: 'Turn head to the right',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        ),
        AdminVerificationItem(
          requestId: 'req-verif-aditya',
          userId: DemoUsers.aditya.id,
          displayName: DemoUsers.aditya.displayName,
          selfieStoragePath: 'selfies/aditya.jpg',
          avatarPath: DemoUsers.aditya.avatarPath,
          instructionCompleted: 'Smile with open mouth',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        ),
      ];
    }

    try {
      final response = await _client.rpc<dynamic>(
        'get_admin_verification_queue',
      );
      final list = response as List<dynamic>? ?? const [];
      return list
          .map(
            (item) =>
                AdminVerificationItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> approveRequest(String requestId, {String? notes}) async {
    if (_client == null || DemoData.enabled) return;

    try {
      await _client.rpc<dynamic>(
        'approve_verification_request',
        params: {'p_request_id': requestId, 'p_notes': notes?.trim()},
      );
    } catch (e) {
      throw Exception('Failed to approve request: ${e.toString()}');
    }
  }

  @override
  Future<void> rejectRequest(String requestId, {required String reason}) async {
    if (_client == null || DemoData.enabled) return;

    final cleanReason = TextSanitizer.limit(reason, 500);
    if (cleanReason.isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    try {
      await _client.rpc<dynamic>(
        'reject_verification_request',
        params: {'p_request_id': requestId, 'p_reason': cleanReason},
      );
    } catch (e) {
      throw Exception('Failed to reject request: ${e.toString()}');
    }
  }

  @override
  Future<String?> getSignedSelfieUrl(String storagePath) async {
    if (_client == null || DemoData.enabled) {
      return DemoImages.avatarKabir;
    }

    try {
      // 5-minute short-lived signed URL for admin review
      final signedUrl = await _client.storage
          .from('verification-selfies')
          .createSignedUrl(storagePath, 300);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }
}

// -----------------------------------------------------------------------------
// Riverpod Providers
// -----------------------------------------------------------------------------

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseVerificationRepository(client);
});

final userVerificationStatusProvider = FutureProvider<UserVerificationState>((
  ref,
) {
  return ref.watch(verificationRepositoryProvider).getVerificationStatus();
});

final adminVerificationQueueProvider =
    FutureProvider<List<AdminVerificationItem>>((ref) {
      return ref.watch(verificationRepositoryProvider).getAdminQueue();
    });
