class MeetingLinkValidator {
  const MeetingLinkValidator._();

  // Accept only HTTPS links from Google Meet, Zoom, or WhatsApp
  static final RegExp _validMeetingLinkRegex = RegExp(
    r'^https://([a-zA-Z0-9-]+\.)?(meet\.google\.com|zoom\.us|call\.whatsapp\.com|chat\.whatsapp\.com)/.+$',
    caseSensitive: false,
  );

  /// Returns true if [url] is a valid HTTPS Google Meet, Zoom, or WhatsApp call link.
  static bool isValid(String? url) {
    if (url == null) return false;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    return _validMeetingLinkRegex.hasMatch(trimmed);
  }

  /// Validates and returns an error message if invalid, or null if valid.
  static String? validate(String? url) {
    if (url == null || url.trim().isEmpty) {
      return 'Please enter a meeting link.';
    }
    final trimmed = url.trim();
    if (!trimmed.toLowerCase().startsWith('https://')) {
      return 'Meeting link must use secure HTTPS (https://...).';
    }
    if (!_validMeetingLinkRegex.hasMatch(trimmed)) {
      return 'Only Google Meet, Zoom, or WhatsApp call links are accepted.';
    }
    return null;
  }

  /// Identifies the service type for visual badges ('google_meet', 'zoom', 'whatsapp', or 'unknown')
  static String getServiceType(String? url) {
    if (url == null) return 'unknown';
    final lower = url.trim().toLowerCase();
    if (lower.contains('meet.google.com')) return 'Google Meet';
    if (lower.contains('zoom.us')) return 'Zoom';
    if (lower.contains('whatsapp.com')) return 'WhatsApp';
    return 'Video Call';
  }
}
