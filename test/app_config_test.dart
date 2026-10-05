import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripfam/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('reports missing configuration without exposing values', () {
      const config = AppConfig(url: '', anonKey: '');

      expect(config.status, BackendConfigurationStatus.missing);
      expect(config.isReady, isFalse);
    });

    test('rejects a Supabase secret key prefix', () {
      const config = AppConfig(
        url: 'https://project.supabase.co',
        anonKey: 'sb_secret_do_not_use',
      );

      expect(config.status, BackendConfigurationStatus.invalid);
    });

    test('rejects a legacy service role JWT', () {
      final payload = base64Url
          .encode(utf8.encode('{"role":"service_role"}'))
          .replaceAll('=', '');
      final config = AppConfig(
        url: 'https://project.supabase.co',
        anonKey: 'header.$payload.signature',
      );

      expect(config.status, BackendConfigurationStatus.invalid);
    });

    test('allows HTTPS and local HTTP only', () {
      const secureConfig = AppConfig(
        url: 'https://project.supabase.co',
        anonKey: 'sb_publishable_public_key',
      );
      const localConfig = AppConfig(
        url: 'http://localhost:54321',
        anonKey: 'sb_publishable_public_key',
      );
      const insecureConfig = AppConfig(
        url: 'http://project.supabase.co',
        anonKey: 'sb_publishable_public_key',
      );

      expect(secureConfig.isReady, isTrue);
      expect(localConfig.isReady, isTrue);
      expect(insecureConfig.status, BackendConfigurationStatus.invalid);
    });
  });
}
