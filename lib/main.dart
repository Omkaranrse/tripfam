import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/errors/app_error_handler.dart';
import 'core/providers/app_providers.dart';
import 'core/theme/app.dart';
import 'core/theme/theme_mode_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.initialize();

  final preferences = await SharedPreferences.getInstance();
  final config = AppConfig.fromEnvironment();
  var backendReady = false;

  if (config.isReady) {
    try {
      await Supabase.initialize(
        url: config.url,
        publishableKey: config.anonKey,
      );
      backendReady = true;
    } on Object {
      backendReady = false;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        supabaseReadyProvider.overrideWithValue(backendReady),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialThemeModeProvider.overrideWithValue(
          storedThemeMode(preferences),
        ),
      ],
      child: const TripMateApp(),
    ),
  );
}
