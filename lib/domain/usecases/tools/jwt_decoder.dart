/// @file jwt_decoder.dart
/// @brief Use case for decoding JSON Web Tokens (JWT).
///
/// Decodes the header and payload of a JWT without verification,
/// providing a structured view of the token's claims including
/// expiration status, issued-at time, and subject.
library;

import 'dart:convert';

import '../usecase.dart';

/// Parameters for the JWT decoder use case.
class JwtDecoderParams {
  /// The raw JWT string to decode (e.g., "eyJhbGci...").
  final String token;

  /// Creates parameter object for JWT decoding.
  ///
  /// [token] - The complete JWT string including all three parts.
  const JwtDecoderParams({required this.token});
}

/// Result of decoding a JWT token.
///
/// Contains the decoded header and payload as maps, along with
/// metadata about the token's structure and expiration status.
@Deprecated('Use JwtDecodeResult instead')
typedef JwtResult = JwtDecodeResult;

/// Result of decoding a JWT token.
class JwtDecodeResult {
  /// The decoded JWT header (algorithm, type, etc.).
  final Map<String, dynamic> header;

  /// The decoded JWT payload (claims).
  final Map<String, dynamic> payload;

  /// The signature portion of the JWT (base64url-encoded, not decoded).
  final String signature;

  /// Whether the token has an expiration claim and it is in the past.
  final bool isExpired;

  /// Human-readable expiration status message.
  final String expirationStatus;

  /// Creates a new [JwtDecodeResult].
  const JwtDecodeResult({
    required this.header,
    required this.payload,
    required this.signature,
    required this.isExpired,
    required this.expirationStatus,
  });
}

/// Decodes a JWT token into its header and payload components.
///
/// This use case performs base64url decoding of the header and payload
/// segments. It does NOT verify the token's signature (cryptographic
/// verification should be done server-side or with a dedicated library).
class JwtDecoder extends UseCase<JwtDecodeResult, JwtDecoderParams> {
  /// Creates a new [JwtDecoder] use case.
  JwtDecoder();

  /// Decodes the JWT token and returns the structured result.
  @override
  Future<JwtDecodeResult> call(JwtDecoderParams params) async {
    final token = params.token.trim();

    // JWT format: header.payload.signature
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException(
        'Invalid JWT format: expected three parts separated by dots (header.payload.signature)',
      );
    }

    // Decode the header (first part).
    final decodedHeader = _decodeBase64Url(parts[0]);

    // Decode the payload (second part).
    final decodedPayload = _decodeBase64Url(parts[1]);

    // The signature (third part) is not decoded — it's a cryptographic value.
    final signature = parts[2];

    // Parse the JSON structures.
    Map<String, dynamic> header;
    Map<String, dynamic> payload;

    try {
      header = json.decode(decodedHeader) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse JWT header as JSON: $e');
    }

    try {
      payload = json.decode(decodedPayload) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Failed to parse JWT payload as JSON: $e');
    }

    // Determine expiration status.
    final expStatus = _getExpirationStatus(payload);

    return JwtDecodeResult(
      header: header,
      payload: payload,
      signature: signature,
      isExpired: expStatus.isExpired,
      expirationStatus: expStatus.message,
    );
  }

  /// Decodes a base64url-encoded string to its UTF-8 string representation.
  ///
  /// Handles standard base64url encoding (no padding) and adds padding
  /// as needed for Dart's built-in base64 decoder.
  String _decodeBase64Url(String input) {
    // Base64url uses '-' and '_' instead of '+' and '/'.
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');

    // Add padding if necessary.
    final remainder = normalized.length % 4;
    if (remainder > 0) {
      normalized += '=' * (4 - remainder);
    }

    return utf8.decode(base64.decode(normalized));
  }

  /// Determines the expiration status of a token from its payload.
  ///
  /// Checks the 'exp' (expiration time) claim and compares it to the
  /// current time. Also provides human-readable timestamps.
  ({bool isExpired, String message}) _getExpirationStatus(
    Map<String, dynamic> payload,
  ) {
    if (!payload.containsKey('exp')) {
      return (
        isExpired: false,
        message: 'No expiration claim (exp) found. Token does not expire.',
      );
    }

    final expValue = payload['exp'];
    int expSeconds;
    if (expValue is int) {
      expSeconds = expValue;
    } else if (expValue is double) {
      expSeconds = expValue.toInt();
    } else {
      return (
        isExpired: false,
        message: 'Expiration claim (exp) has invalid type: ${expValue.runtimeType}',
      );
    }

    final expDate = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
    final now = DateTime.now();
    final isExpired = now.isAfter(expDate);

    // Build a descriptive status message.
    final buffer = StringBuffer();
    if (isExpired) {
      buffer.write('EXPIRED');
      buffer.write(' — expired on ');
    } else {
      buffer.write('VALID');
      buffer.write(' — expires on ');
    }
    buffer.write(expDate.toUtc().toIso8601String());
    buffer.write(' (UTC)');

    // Add additional context: time until expiry or time since expiry.
    final difference = expDate.difference(now);
    if (isExpired) {
      buffer.write(' — expired ');
      buffer.write(_formatDuration(difference.abs()));
      buffer.write(' ago');
    } else {
      buffer.write(' — expires in ');
      buffer.write(_formatDuration(difference));
    }

    // Show issued-at time if present.
    if (payload.containsKey('iat')) {
      final iatValue = payload['iat'];
      int? iatSeconds;
      if (iatValue is int) {
        iatSeconds = iatValue;
      } else if (iatValue is double) {
        iatSeconds = iatValue.toInt();
      }
      if (iatSeconds != null) {
        final iatDate =
            DateTime.fromMillisecondsSinceEpoch(iatSeconds * 1000).toUtc();
        buffer.write(' — issued at ');
        buffer.write(iatDate.toIso8601String());
      }
    }

    return (isExpired: isExpired, message: buffer.toString());
  }

  /// Formats a [Duration] into a human-readable string.
  ///
  /// Examples: "2 hours 15 minutes", "30 seconds", "1 day 3 hours"
  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    final parts = <String>[];
    if (days > 0) parts.add('$days day${days > 1 ? "s" : ""}');
    if (hours > 0) parts.add('$hours hour${hours > 1 ? "s" : ""}');
    if (minutes > 0) parts.add('$minutes minute${minutes > 1 ? "s" : ""}');
    if (seconds > 0 || parts.isEmpty) {
      parts.add('$seconds second${seconds != 1 ? "s" : ""}');
    }

    return parts.join(' ');
  }
}