/// @file method_chip.dart
/// @brief Colour-coded chip that displays an HTTP method name.
///
/// Each HTTP method is assigned a distinct colour so users can
/// visually scan request lists and identify the method at a glance.
library;

import 'package:flutter/material.dart';

import '../../../domain/entities/api_request.dart';

/// Colour mapping for each [HttpMethod].
///
/// These colours are chosen for maximum contrast and semantic meaning:
/// - GET → green (safe, read-only)
/// - POST → blue (create)
/// - PUT → orange (replace)
/// - PATCH → teal (partial update)
/// - DELETE → red (destructive)
/// - HEAD → grey (metadata only)
/// - OPTIONS → purple (CORS / discovery)
const _methodColors = <HttpMethod, Color>{
  HttpMethod.get: Color(0xFF43A047),
  HttpMethod.post: Color(0xFF1E88E5),
  HttpMethod.put: Color(0xFFFB8C00),
  HttpMethod.patch: Color(0xFF00897B),
  HttpMethod.delete: Color(0xFFE53935),
  HttpMethod.head: Color(0xFF78909C),
  HttpMethod.options: Color(0xFF7B1FA2),
};

/// A compact, colour-coded chip showing an HTTP method name.
///
/// The chip background uses the method colour at 15 % opacity while the
/// text uses the full colour for maximum readability on both light and
/// dark backgrounds.
///
/// Example:
/// ```dart
/// MethodChip(method: HttpMethod.post)
/// ```
class MethodChip extends StatelessWidget {
  /// The HTTP method to display.
  final HttpMethod method;

  /// Optional size override for the font. Defaults to `null` (theme default).
  final double? fontSize;

  /// Padding around the text. Defaults to horizontal 8, vertical 2.
  final EdgeInsetsGeometry? padding;

  /// Creates a [MethodChip].
  const MethodChip({
    super.key,
    required this.method,
    this.fontSize,
    this.padding,
  });

  /// The display label for the method (uppercase 3-7 letter string).
  String get _label => switch (method) {
        HttpMethod.get => 'GET',
        HttpMethod.post => 'POST',
        HttpMethod.put => 'PUT',
        HttpMethod.patch => 'PATCH',
        HttpMethod.delete => 'DELETE',
        HttpMethod.head => 'HEAD',
        HttpMethod.options => 'OPTIONS',
      };

  /// The semantic colour for this method.
  Color get _color => _methodColors[method] ?? Colors.grey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: (fontSize != null
                ? TextStyle(fontSize: fontSize)
                : style.labelMedium)
            ?.copyWith(
          fontWeight: FontWeight.w700,
          color: _color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// A variant that renders from a raw string (useful for history entries
/// where the method is stored as a plain string).
///
/// Falls back to grey for unrecognised methods.
class MethodChipFromString extends StatelessWidget {
  /// The HTTP method string (e.g. `"GET"`, `"POST"`).
  final String method;

  /// Creates a [MethodChipFromString].
  const MethodChipFromString({super.key, required this.method});

  /// Attempts to parse [method] into an [HttpMethod] enum value.
  HttpMethod get _parsed => HttpMethod.values.firstWhere(
        (m) => m.name.toUpperCase() == method.toUpperCase(),
        orElse: () => HttpMethod.get,
      );

  @override
  Widget build(BuildContext context) {
    return MethodChip(method: _parsed);
  }
}