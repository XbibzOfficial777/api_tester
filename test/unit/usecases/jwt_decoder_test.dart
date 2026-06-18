import 'dart:convert';
import 'package:test/test.dart';
import 'package:api_tester/domain/usecases/tools/jwt_decoder.dart';

/// Helper to create a JWT from header and payload maps and a dummy signature.
///
/// Uses base64url encoding without padding (standard JWT encoding).
String _buildTestJwt(Map<String, dynamic> header, Map<String, dynamic> payload) {
  String base64UrlEncode(String input) {
    final bytes = utf8.encode(input);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  final headerB64 = base64UrlEncode(jsonEncode(header));
  final payloadB64 = base64UrlEncode(jsonEncode(payload));
  // Dummy signature (we only test decoding, not verification).
  const signature = 'dummysignature';
  return '$headerB64.$payloadB64.$signature';
}

/// Creates a JWT that has already expired.
String _buildExpiredJwt() {
  // Set exp to Jan 1, 2020 (well in the past).
  return _buildTestJwt(
    {'alg': 'HS256', 'typ': 'JWT'},
    {
      'sub': '1234567890',
      'name': 'Test User',
      'iat': 1577836800,
      'exp': 1577836800, // 2020-01-01T00:00:00Z
    },
  );
}

/// Creates a JWT that expires far in the future.
String _buildValidJwt() {
  // Set exp to Jan 1, 2100.
  return _buildTestJwt(
    {'alg': 'HS256', 'typ': 'JWT'},
    {
      'sub': '1234567890',
      'name': 'Test User',
      'iat': 1700000000,
      'exp': 4102444800, // 2100-01-01T00:00:00Z
    },
  );
}

void main() {
  late JwtDecoder jwtDecoder;

  setUp(() {
    jwtDecoder = JwtDecoder();
  });

  group('JwtDecoder', () {
    group('decoding a valid JWT token', () {
      test('decodes header and payload correctly', () async {
        final token = _buildValidJwt();
        final result = await jwtDecoder(JwtDecoderParams(token: token));

        expect(result.header['alg'], equals('HS256'));
        expect(result.header['typ'], equals('JWT'));
        expect(result.payload['sub'], equals('1234567890'));
        expect(result.payload['name'], equals('Test User'));
      });

      test('returns the raw signature string', () async {
        final token = _buildValidJwt();
        final result = await jwtDecoder(JwtDecoderParams(token: token));

        expect(result.signature, equals('dummysignature'));
      });
    });

    group('header extraction', () {
      test('extracts alg field', () async {
        final token = _buildTestJwt(
          {'alg': 'RS256', 'typ': 'JWT'},
          {'sub': 'test'},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.header['alg'], equals('RS256'));
      });

      test('extracts typ field', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'sub': 'test'},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.header['typ'], equals('JWT'));
      });

      test('extracts additional header fields', () async {
        final token = _buildTestJwt(
          {'alg': 'ES256', 'typ': 'JWT', 'kid': 'key-1'},
          {'sub': 'test'},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.header['kid'], equals('key-1'));
      });
    });

    group('payload extraction', () {
      test('extracts string payload fields', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'name': 'Alice', 'role': 'admin'},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.payload['name'], equals('Alice'));
        expect(result.payload['role'], equals('admin'));
      });

      test('extracts numeric payload fields', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'userId': 42, 'score': 99.5},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.payload['userId'], equals(42));
        expect(result.payload['score'], equals(99.5));
      });

      test('extracts array payload fields', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'roles': ['admin', 'user']},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.payload['roles'], equals(['admin', 'user']));
      });

      test('extracts nested object payload fields', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'profile': {'email': 'a@b.com'}},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.payload['profile']['email'], equals('a@b.com'));
      });
    });

    group('expiration detection', () {
      test('detects expired token', () async {
        final token = _buildExpiredJwt();
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.isExpired, isTrue);
        expect(result.expirationStatus, contains('EXPIRED'));
      });

      test('detects non-expired token', () async {
        final token = _buildValidJwt();
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.isExpired, isFalse);
        expect(result.expirationStatus, contains('VALID'));
      });

      test('expiration status includes the expiration date', () async {
        final token = _buildValidJwt();
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        // The exp is set to 2100-01-01.
        expect(result.expirationStatus, contains('2100'));
      });
    });

    group('error handling for invalid JWT', () {
      test('throws FormatException for token with wrong number of parts', () async {
        const token = 'only.two.parts';
        expect(
          () => jwtDecoder(JwtDecoderParams(token: token)),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for token with only one part', () async {
        expect(
          () => jwtDecoder(JwtDecoderParams(token: 'singlepart')),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for token with invalid base64 in header', () async {
        // The header part contains characters that aren't valid base64url.
        const token = '!!!invalid!!!.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dummysig';
        expect(
          () => jwtDecoder(JwtDecoderParams(token: token)),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws FormatException for non-JSON payload', () async {
        // Header is valid JSON, payload is not.
        final headerB64 = base64Url
            .encode(utf8.encode('{"alg":"HS256"}'))
            .replaceAll('=', '');
        final payloadB64 = base64Url
            .encode(utf8.encode('not-json'))
            .replaceAll('=', '');
        const signature = 'sig';
        final token = '$headerB64.$payloadB64.$signature';

        expect(
          () => jwtDecoder(JwtDecoderParams(token: token)),
          throwsA(isA<FormatException>()),
        );
      });

      test('handles token with leading/trailing whitespace', () async {
        final token = ' ${_buildValidJwt()} ';
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.payload['sub'], isNotNull);
      });
    });

    group('token without expiration claim', () {
      test('isExpired is false when no exp claim exists', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'sub': '123', 'name': 'No Expiry'},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.isExpired, isFalse);
        expect(result.expirationStatus,
            contains('No expiration claim'));
      });

      test('includes issued-at time in status when iat is present', () async {
        final token = _buildTestJwt(
          {'alg': 'HS256', 'typ': 'JWT'},
          {'sub': '123', 'iat': 1700000000, 'exp': 4102444800},
        );
        final result = await jwtDecoder(JwtDecoderParams(token: token));
        expect(result.expirationStatus, contains('issued at'));
      });
    });
  });
}