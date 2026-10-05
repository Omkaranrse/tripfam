import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_providers.dart';

const _themeModeKey = 'theme_mode';

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

ThemeMode storedThemeMode(SharedPreferences preferences) {
  final savedName = preferences.getString(_themeModeKey);
  for (final mode in ThemeMode.values) {
    if (mode.name == savedName) {
      return mode;
    }
  }
  return ThemeMode.system;
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  Future<bool> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      return await ref
          .read(sharedPreferencesProvider)
          .setString(_themeModeKey, mode.name);
    } on Object {
      return false;
    }
  }
}
