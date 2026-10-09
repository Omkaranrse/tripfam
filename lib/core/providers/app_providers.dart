import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig(url: '', anonKey: ''),
);

final firebaseReadyProvider = Provider<bool>((ref) => false);

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  return ref.watch(firebaseReadyProvider) ? FirebaseAuth.instance : null;
});

final firestoreProvider = Provider<FirebaseFirestore?>((ref) {
  return ref.watch(firebaseReadyProvider) ? FirebaseFirestore.instance : null;
});

// Backward compatibility provider for legacy components
final supabaseReadyProvider = Provider<bool>((ref) => false);

final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => null,
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences were not initialized.'),
);
