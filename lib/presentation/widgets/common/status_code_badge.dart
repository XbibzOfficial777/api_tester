/// @file status_code_badge.dart
/// @brief Colour-coded badge for displaying HTTP status codes.
///
/// Uses the semantic colour system from [AppTheme] to colour the badge
/// based on the status code class (1xx → grey, 2xx → green, etc.).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A compact badge showing an HTTP status code with semantic colouring.
///
/// The background uses the status colour at low opacity while the text
/// uses the full colour, making it readable on both light and dark themes.
///
/// Example:
/// ```dart
/// StatusCodeBadge(statusCode: 200)  // green badge showing "200 OK"
/// StatusCodeBadge(statusCode: 404)  // orange badge showing "404 Not Found"
/// ```
class StatusCodeBadge extends StatelessWidget {
  /// The HTTP status code to display. A value of `0` or `null` indicates
  /// no response (e.g. network error).
  final int? statusCode;

  /// Optional size override for the status number text.
  final double? fontSize;

  /// Whether to show the standard reason phrase alongside the number.
  /// Defaults to `true`.
  final bool showReasonPhrase;

  /// Creates a [StatusCodeBadge].
  const StatusCodeBadge({
    super.key,
    this.statusCode,
    this.fontSize,
    this.showReasonPhrase = true,
  });

  /// Standard HTTP reason phrases mapped by status code.
  static const Map<int, String> _reasonPhrases = {
    100: 'Continue',
    101: 'Switching Protocols',
    200: 'OK',
    201: 'Created',
    204: 'No Content',
    301: 'Moved Permanently',
    302: 'Found',
    304: 'Not Modified',
    307: 'Temporary Redirect',
    308: 'Permanent Redirect',
    400: 'Bad Request',
    401: 'Unauthorized',
    403: 'Forbidden',
    404: 'Not Found',
    405: 'Method Not Allowed',
    408: 'Request Timeout',
    409: 'Conflict',
    422: 'Unprocessable Entity',
    429: 'Too Many Requests',
    500: 'Internal Server Error',
    502: 'Bad Gateway',
    503: 'Service Unavailable',
    504: 'Gateway Timeout',
  };

  /// Returns the reason phrase for [code], or a generic label.
  String _reasonPhrase(int code) {
    if (_reasonPhrases.containsKey(code)) return _reasonPhrases[code]!;
    if (code >= 100 && code < 200) return 'Informational';
    if (code >= 200 && code < 300) return 'Success';
    if (code >= 300 && code < 400) return 'Redirection';
    if (code >= 400 && code < 500) return 'Client Error';
    if (code >= 500) return 'Server Error';
    return 'Unknown';
  }

  /// The semantic colour for the status code.
  Color get _color {
    if (statusCode == null || statusCode == 0) return Colors.grey;
    return AppTheme.statusCodeColor(statusCode!);
  }

  /// The background colour (same hue at low opacity).
  Color get _bgColor {
    if (statusCode == null || statusCode == 0) return Colors.grey.withOpacity(0.15);
    return AppTheme.statusCodeBackgroundColor(statusCode!);
  }

  @override
  Widget build(BuildContext context) {
    // When there's no status code, show a neutral "N/A" badge.
    if (statusCode == null || statusCode == 0) {
      return _buildBadge(context, 'N/A', '');
    }

    final label = '$statusCode';
    final phrase = showReasonPhrase ? ' ${_reasonPhrase(statusCode!)}' : '';
    return _buildBadge(context, label, phrase);
  }

  /// Builds the actual badge container.
  Widget _buildBadge(BuildContext context, String code, String phrase) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: code,
              style: (fontSize != null
                      ? TextStyle(fontSize: fontSize)
                      : textTheme.labelMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
            if (phrase.isNotEmpty)
              TextSpan(
                text: phrase,
                style: (fontSize != null
                        ? TextStyle(fontSize: (fontSize ?? 12) - 2)
                        : textTheme.labelSmall)
                    ?.copyWith(
                  color: _color.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}