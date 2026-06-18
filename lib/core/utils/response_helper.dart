/// @file response_helper.dart
/// @brief Formatting and utility helpers for HTTP response data.
///
/// Stateless utility functions for common presentation tasks: formatting
/// byte sizes, elapsed times, mapping status codes to colours and
/// descriptions, copying text to the clipboard, and sharing content with
/// the system share sheet. Every function is a pure helper with no side
/// effects except for the clipboard and share actions which are explicitly
/// platform-invoking.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';

/// Container for response-presentation utility methods.
///
/// All methods are static to allow call-site access without instantiation:
/// ```dart
/// final readable = ResponseHelper.formatBytes(2048);
/// final colour   = ResponseHelper.getStatusColor(200);
/// ```
class ResponseHelper {
  ResponseHelper._();

  // ---------------------------------------------------------------------------
  // Byte Formatting
  // ---------------------------------------------------------------------------

  /// Formats a raw byte count into a human-readable string.
  ///
  /// | Bytes  | Output |
  /// |--------|--------|
  /// | 512    | `512 B` |
  /// | 1024   | `1.0 KB` |
  /// | 1048576 | `1.0 MB` |
  /// | 1073741824 | `1.0 GB` |
  ///
  /// Values are displayed with one decimal place for KB and above.
  static String formatBytes(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ---------------------------------------------------------------------------
  // Time Formatting
  // ---------------------------------------------------------------------------

  /// Formats a duration in milliseconds into a compact, readable string.
  ///
  /// | Input  | Output     |
  /// |--------|------------|
  /// | 45     | `45 ms`    |
  /// | 1500   | `1.5 s`    |
  /// | 65000  | `1.1 min`  |
  /// | 3700000| `1.0 hr`   |
  static String formatDuration(int milliseconds) {
    if (milliseconds < 0) return '0 ms';
    if (milliseconds < 1000) return '$milliseconds ms';
    if (milliseconds < 60000) {
      return '${(milliseconds / 1000).toStringAsFixed(1)} s';
    }
    if (milliseconds < 3600000) {
      final minutes = milliseconds / 60000;
      return '${minutes.toStringAsFixed(1)} min';
    }
    final hours = milliseconds / 3600000;
    return '${hours.toStringAsFixed(1)} hr';
  }

  // ---------------------------------------------------------------------------
  // Status Code Helpers
  // ---------------------------------------------------------------------------

  /// Returns the semantic colour associated with an HTTP status code.
  ///
  /// Delegates to [AppTheme.statusCodeColor] so the colour palette is
  /// managed in a single place. See that method for the full mapping.
  static Color getStatusColor(int statusCode) {
    return AppTheme.statusCodeColor(statusCode);
  }

  /// Returns the background tint colour for a status-code badge/chip.
  ///
  /// Delegates to [AppTheme.statusCodeBackgroundColor].
  static Color getStatusBackgroundColor(int statusCode) {
    return AppTheme.statusCodeBackgroundColor(statusCode);
  }

  /// Returns a human-readable description for common HTTP status codes.
  ///
  /// Covers the most frequently encountered codes. Unrecognised codes
  /// return `"HTTP $statusCode"`.
  ///
  /// ```dart
  /// ResponseHelper.getStatusCodeDescription(200); // "OK"
  /// ResponseHelper.getStatusCodeDescription(404); // "Not Found"
  /// ```
  static String getStatusCodeDescription(int statusCode) {
    switch (statusCode) {
      // 1xx – Informational
      case 100: return 'Continue';
      case 101: return 'Switching Protocols';
      case 102: return 'Processing';
      case 103: return 'Early Hints';

      // 2xx – Success
      case 200: return 'OK';
      case 201: return 'Created';
      case 202: return 'Accepted';
      case 203: return 'Non-Authoritative Information';
      case 204: return 'No Content';
      case 205: return 'Reset Content';
      case 206: return 'Partial Content';
      case 207: return 'Multi-Status';
      case 208: return 'Already Reported';
      case 226: return 'IM Used';

      // 3xx – Redirection
      case 300: return 'Multiple Choices';
      case 301: return 'Moved Permanently';
      case 302: return 'Found';
      case 303: return 'See Other';
      case 304: return 'Not Modified';
      case 305: return 'Use Proxy';
      case 307: return 'Temporary Redirect';
      case 308: return 'Permanent Redirect';

      // 4xx – Client Errors
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 402: return 'Payment Required';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 405: return 'Method Not Allowed';
      case 406: return 'Not Acceptable';
      case 407: return 'Proxy Authentication Required';
      case 408: return 'Request Timeout';
      case 409: return 'Conflict';
      case 410: return 'Gone';
      case 411: return 'Length Required';
      case 412: return 'Precondition Failed';
      case 413: return 'Payload Too Large';
      case 414: return 'URI Too Long';
      case 415: return 'Unsupported Media Type';
      case 416: return 'Range Not Satisfiable';
      case 417: return 'Expectation Failed';
      case 418: return "I'm a Teapot";
      case 422: return 'Unprocessable Entity';
      case 423: return 'Locked';
      case 424: return 'Failed Dependency';
      case 425: return 'Too Early';
      case 426: return 'Upgrade Required';
      case 428: return 'Precondition Required';
      case 429: return 'Too Many Requests';
      case 431: return 'Request Header Fields Too Large';
      case 451: return 'Unavailable For Legal Reasons';

      // 5xx – Server Errors
      case 500: return 'Internal Server Error';
      case 501: return 'Not Implemented';
      case 502: return 'Bad Gateway';
      case 503: return 'Service Unavailable';
      case 504: return 'Gateway Timeout';
      case 505: return 'HTTP Version Not Supported';
      case 506: return 'Variant Also Negotiates';
      case 507: return 'Insufficient Storage';
      case 508: return 'Loop Detected';
      case 510: return 'Not Extended';
      case 511: return 'Network Authentication Required';

      default:
        return 'HTTP $statusCode';
    }
  }

  // ---------------------------------------------------------------------------
  // Clipboard
  // ---------------------------------------------------------------------------

  /// Copies [text] to the system clipboard and optionally shows a [snackBar].
  ///
  /// The clipboard operation is silent unless a non-null [scaffoldMessenger]
  /// is provided, in which case a brief "Copied to clipboard" message is
  /// displayed.
  static Future<void> copyToClipboard(
    String text, {
    ScaffoldMessengerState? scaffoldMessenger,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    scaffoldMessenger?.showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Share
  // ---------------------------------------------------------------------------

  /// Opens the system share sheet with the given [text].
  ///
  /// Optionally accepts a [subject] line (used by email clients).
  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
