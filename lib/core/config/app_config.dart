import 'dart:convert';

enum BackendConfigurationStatus { missing, invalid, ready }

class AppConfig {
  const AppConfig({required this.url, required this.anonKey});

  static const defaultUrl = 'https://eikyglodqwcdlrporqzh.supabase.co';
  static const defaultAnonKey =
      'sb_publishable_FOppxeCH1_jimVn-L0UyAg_hedzqWVP';

  factory AppConfig.fromEnvironment() {
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final trimmedUrl = envUrl.trim();
    final trimmedKey = envAnonKey.trim();

    return AppConfig(
      url: trimmedUrl.isNotEmpty ? trimmedUrl : defaultUrl,
      anonKey: trimmedKey.isNotEmpty ? trimmedKey : defaultAnonKey,
    );
  }

  final String url;
  final String anonKey;

  BackendConfigurationStatus get status {
    if (url.isEmpty && anonKey.isEmpty) {
      return BackendConfigurationStatus.missing;
    }
    if (url.isEmpty || anonKey.isEmpty || !_hasAllowedUrl || _isSecretKey) {
      return BackendConfigurationStatus.invalid;
    }
    return BackendConfigurationStatus.ready;
  }

  bool get isReady => status == BackendConfigurationStatus.ready;

  bool get _hasAllowedUrl {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || uri.userInfo.isNotEmpty) {
      return false;
    }
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      return false;
    }
    final isLocalHost = const {
      'localhost',
      '127.0.0.1',
      '::1',
    }.contains(uri.host);
    return uri.scheme == 'https' || (uri.scheme == 'http' && isLocalHost);
  }

  bool get _isSecretKey {
    if (anonKey.startsWith('sb_secret_')) {
      return true;
    }

    final segments = anonKey.split('.');
    if (segments.length != 3) {
      return false;
    }
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      );
      return payload is Map<String, dynamic> &&
          payload['role'] == 'service_role';
    } on Object {
      return false;
    }
  }
}
