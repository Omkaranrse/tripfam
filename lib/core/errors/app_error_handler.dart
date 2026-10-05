import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppErrorHandler {
  static void initialize() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint('[GlobalFlutterError] ${details.exceptionAsString()}');
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) {
        debugPrint('[GlobalPlatformError] $error\n$stack');
      }
      return true; // Error handled safely
    };
  }

  static String safeMessage(Object? error) {
    if (error == null) {
      return 'An unexpected issue occurred. Please try again.';
    }

    final message = error.toString().toLowerCase();

    if (message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timed out') ||
        message.contains('clientexception')) {
      return 'Unable to reach the server. Please check your internet connection.';
    }

    if (message.contains('unauthorized') ||
        message.contains('jwt') ||
        message.contains('token') ||
        message.contains('401') ||
        message.contains('session')) {
      return 'Your session has expired or requires sign-in. Please log in again.';
    }

    if (message.contains('permission') ||
        message.contains('forbidden') ||
        message.contains('403') ||
        message.contains('42501')) {
      return 'You do not have permission to perform this action.';
    }

    if (message.contains('not found') || message.contains('404')) {
      return 'The requested travel item or profile was not found.';
    }

    if (message.contains('capacity') || message.contains('full')) {
      return 'This trip has already reached its maximum participant limit.';
    }

    return 'Something went wrong while processing your request. Please try again.';
  }

  static void showSafeSnackBar(
    BuildContext context,
    Object? error, {
    String? fallbackMessage,
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final message = fallbackMessage ?? safeMessage(error);

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onError,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onError),
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.error,
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: theme.colorScheme.onError,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}
