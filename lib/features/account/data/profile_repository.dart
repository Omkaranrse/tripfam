import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/demo/demo_data.dart';
import '../../../core/providers/app_providers.dart';
import '../domain/user_profile.dart';
import 'auth_repository.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> getMyProfile();
  Future<UserProfile?> getProfileById(String userId);
  Future<UserProfile> updateProfile(UserProfile profile);
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  });
  Future<String?> getAvatarSignedUrl(String path, {int expiresIn = 3600});
  Future<void> deleteAccount();
  Future<Map<String, dynamic>> exportUserData();
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<UserProfile?> getMyProfile() async {
    if (_client == null || DemoData.enabled) {
      return DemoUsers.currentUser;
    }
    final client = _client;
    final user = client.auth.currentUser;
    if (user == null) return null;
    return getProfileById(user.id);
  }

  @override
  Future<UserProfile?> getProfileById(String userId) async {
    if (_client == null || DemoData.enabled) {
      return DemoUsers.getById(userId);
    }
    final client = _client;
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (_) {
      return DemoUsers.getById(userId);
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    if (_client == null || DemoData.enabled) {
      return profile;
    }
    final client = _client;
    final user = client.auth.currentUser;
    if (user == null || user.id != profile.id) {
      throw Exception('Authentication required to modify profile.');
    }

    final updatePayload = profile.toUpdateJson();

    try {
      final response = await client
          .from('profiles')
          .update(updatePayload)
          .eq('id', user.id)
          .select()
          .single();

      return UserProfile.fromJson(response);
    } catch (_) {
      throw Exception('Failed to update profile. Please verify your details.');
    }
  }

  @override
  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Backend service is not configured.');
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to upload an avatar.');
    }

    // Validate file size limit (5MB)
    const maxSizeBytes = 5 * 1024 * 1024;
    if (bytes.lengthInBytes > maxSizeBytes) {
      throw Exception('Avatar image exceeds maximum allowed size of 5MB.');
    }

    // Validate supported MIME types
    final ext = fileExtension.toLowerCase().replaceAll('.', '');
    const allowedExts = {'jpg', 'jpeg', 'png', 'webp'};
    if (!allowedExts.contains(ext)) {
      throw Exception('Only JPG, PNG, and WebP image formats are accepted.');
    }

    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storagePath = '${user.id}/$fileName';

    try {
      await client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );

      return storagePath;
    } catch (_) {
      throw Exception('Failed to upload avatar image to secure storage.');
    }
  }

  @override
  Future<String?> getAvatarSignedUrl(
    String path, {
    int expiresIn = 3600,
  }) async {
    final client = _client;
    if (client == null || path.isEmpty) return null;
    try {
      final signedUrl = await client.storage
          .from('avatars')
          .createSignedUrl(path, expiresIn);
      return signedUrl;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteAccount() async {
    final client = _client;
    if (client == null) {
      throw Exception('Backend service is not configured.');
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to delete account.');
    }

    try {
      await client.rpc<void>('delete_user_account');
      await client.auth.signOut();
    } catch (_) {
      throw Exception('Failed to delete account. Please try again later.');
    }
  }

  @override
  Future<Map<String, dynamic>> exportUserData() async {
    final client = _client;
    if (client == null) {
      throw Exception('Backend service is not configured.');
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required to export your data.');
    }

    try {
      final response = await client.rpc<Map<String, dynamic>>(
        'export_user_data',
      );
      return response;
    } catch (_) {
      throw Exception(
        'Unable to export account data at this time. Please try again later.',
      );
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseProfileRepository(client);
});

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      if (DemoData.enabled) {
        return DemoUsers.currentUser;
      }
      return null;
    }
    return ref.watch(profileRepositoryProvider).getMyProfile();
  }

  Future<void> updateProfile(UserProfile updated) async {
    state = const AsyncValue.loading();
    try {
      final result = await ref
          .read(profileRepositoryProvider)
          .updateProfile(updated);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
      UserProfileNotifier.new,
    );

final isProfileCompleteProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.value?.isProfileComplete ?? false;
});
