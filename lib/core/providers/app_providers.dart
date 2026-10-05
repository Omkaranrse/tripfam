import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig(url: '', anonKey: ''),
);

final supabaseReadyProvider = Provider<bool>((ref) => false);

final supabaseClientProvider = Provider<SupabaseClient?>(
  (ref) => ref.watch(supabaseReadyProvider) ? Supabase.instance.client : null,
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences were not initialized.'),
);
