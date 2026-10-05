abstract final class TextSanitizer {
  static final RegExp _tagPattern = RegExp(r'<[^>]*>', multiLine: true);
  static final RegExp _controlCharPattern = RegExp(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]',
  );

  /// Strips raw HTML tags and dangerous control characters from user text.
  static String sanitize(String? raw) {
    if (raw == null) return '';
    final withoutTags = raw.replaceAll(_tagPattern, '');
    final clean = withoutTags.replaceAll(_controlCharPattern, '');
    return clean.trim();
  }

  /// Ensures text length does not exceed [maxLength] after sanitization.
  static String limit(String? raw, int maxLength) {
    final clean = sanitize(raw);
    if (clean.length <= maxLength) return clean;
    return clean.substring(0, maxLength);
  }
}
