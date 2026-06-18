import 'package:flutter_test/flutter_test.dart';
import 'package:api_tester/core/utils/response_helper.dart';
import 'package:api_tester/core/theme/app_theme.dart';

void main() {
  group('ResponseHelper.formatBytes', () {
    test('formats 0 bytes correctly', () {
      expect(ResponseHelper.formatBytes(0), equals('0 B'));
    });

    test('formats bytes less than 1024 as bytes', () {
      expect(ResponseHelper.formatBytes(500), equals('500 B'));
      expect(ResponseHelper.formatBytes(1), equals('1 B'));
      expect(ResponseHelper.formatBytes(1023), equals('1023 B'));
    });

    test('formats 1024 bytes as 1.0 KB', () {
      expect(ResponseHelper.formatBytes(1024), equals('1.0 KB'));
    });

    test('formats bytes in KB range', () {
      expect(ResponseHelper.formatBytes(2048), equals('2.0 KB'));
      expect(ResponseHelper.formatBytes(5120), equals('5.0 KB'));
    });

    test('formats 1 MB (1048576 bytes)', () {
      expect(ResponseHelper.formatBytes(1048576), equals('1.0 MB'));
    });

    test('formats bytes in MB range', () {
      expect(ResponseHelper.formatBytes(5242880), equals('5.0 MB'));
    });

    test('formats 1 GB (1073741824 bytes)', () {
      expect(ResponseHelper.formatBytes(1073741824), equals('1.0 GB'));
    });

    test('formats negative bytes as 0 B', () {
      expect(ResponseHelper.formatBytes(-1), equals('0 B'));
      expect(ResponseHelper.formatBytes(-500), equals('0 B'));
    });
  });

  group('ResponseHelper.formatDuration', () {
    test('formats milliseconds as ms when < 1000', () {
      expect(ResponseHelper.formatDuration(100), equals('100 ms'));
      expect(ResponseHelper.formatDuration(0), equals('0 ms'));
      expect(ResponseHelper.formatDuration(999), equals('999 ms'));
    });

    test('formats seconds when >= 1000 and < 60000', () {
      expect(ResponseHelper.formatDuration(1000), equals('1.0 s'));
      expect(ResponseHelper.formatDuration(1500), equals('1.5 s'));
      expect(ResponseHelper.formatDuration(30000), equals('30.0 s'));
    });

    test('formats minutes when >= 60000 and < 3600000', () {
      expect(ResponseHelper.formatDuration(60000), equals('1.0 min'));
      expect(ResponseHelper.formatDuration(65000), equals('1.1 min'));
      expect(ResponseHelper.formatDuration(120000), equals('2.0 min'));
    });

    test('formats hours when >= 3600000', () {
      expect(ResponseHelper.formatDuration(3600000), equals('1.0 hr'));
      expect(ResponseHelper.formatDuration(3700000), equals('1.0 hr'));
      expect(ResponseHelper.formatDuration(7200000), equals('2.0 hr'));
    });

    test('formats negative milliseconds as 0 ms', () {
      expect(ResponseHelper.formatDuration(-1), equals('0 ms'));
    });
  });

  group('ResponseHelper.getStatusColor', () {
    test('returns grey color for 0 (no response)', () {
      expect(ResponseHelper.getStatusColor(0), equals(Colors.grey));
    });

    test('returns 1xx color for informational status codes', () {
      expect(ResponseHelper.getStatusColor(100), equals(AppTheme.status1xx));
      expect(ResponseHelper.getStatusColor(150), equals(AppTheme.status1xx));
      expect(ResponseHelper.getStatusColor(199), equals(AppTheme.status1xx));
    });

    test('returns 2xx color for success status codes', () {
      expect(ResponseHelper.getStatusColor(200), equals(AppTheme.status2xx));
      expect(ResponseHelper.getStatusColor(201), equals(AppTheme.status2xx));
      expect(ResponseHelper.getStatusColor(299), equals(AppTheme.status2xx));
    });

    test('returns 3xx color for redirection status codes', () {
      expect(ResponseHelper.getStatusColor(300), equals(AppTheme.status3xx));
      expect(ResponseHelper.getStatusColor(301), equals(AppTheme.status3xx));
      expect(ResponseHelper.getStatusColor(399), equals(AppTheme.status3xx));
    });

    test('returns 4xx color for client error status codes', () {
      expect(ResponseHelper.getStatusColor(400), equals(AppTheme.status4xx));
      expect(ResponseHelper.getStatusColor(404), equals(AppTheme.status4xx));
      expect(ResponseHelper.getStatusColor(499), equals(AppTheme.status4xx));
    });

    test('returns 5xx color for server error status codes', () {
      expect(ResponseHelper.getStatusColor(500), equals(AppTheme.status5xx));
      expect(ResponseHelper.getStatusColor(502), equals(AppTheme.status5xx));
      expect(ResponseHelper.getStatusColor(503), equals(AppTheme.status5xx));
    });

    test('returns grey for status < 100', () {
      expect(ResponseHelper.getStatusColor(99), equals(Colors.grey));
      expect(ResponseHelper.getStatusColor(-1), equals(Colors.grey));
    });
  });

  group('ResponseHelper.getStatusCodeDescription', () {
    test('returns correct descriptions for common 1xx codes', () {
      expect(ResponseHelper.getStatusCodeDescription(100), equals('Continue'));
      expect(ResponseHelper.getStatusCodeDescription(101), equals('Switching Protocols'));
    });

    test('returns correct descriptions for common 2xx codes', () {
      expect(ResponseHelper.getStatusCodeDescription(200), equals('OK'));
      expect(ResponseHelper.getStatusCodeDescription(201), equals('Created'));
      expect(ResponseHelper.getStatusCodeDescription(204), equals('No Content'));
      expect(ResponseHelper.getStatusCodeDescription(206), equals('Partial Content'));
    });

    test('returns correct descriptions for common 3xx codes', () {
      expect(ResponseHelper.getStatusCodeDescription(301), equals('Moved Permanently'));
      expect(ResponseHelper.getStatusCodeDescription(302), equals('Found'));
      expect(ResponseHelper.getStatusCodeDescription(304), equals('Not Modified'));
      expect(ResponseHelper.getStatusCodeDescription(307), equals('Temporary Redirect'));
    });

    test('returns correct descriptions for common 4xx codes', () {
      expect(ResponseHelper.getStatusCodeDescription(400), equals('Bad Request'));
      expect(ResponseHelper.getStatusCodeDescription(401), equals('Unauthorized'));
      expect(ResponseHelper.getStatusCodeDescription(403), equals('Forbidden'));
      expect(ResponseHelper.getStatusCodeDescription(404), equals('Not Found'));
      expect(ResponseHelper.getStatusCodeDescription(405), equals('Method Not Allowed'));
      expect(ResponseHelper.getStatusCodeDescription(408), equals('Request Timeout'));
      expect(ResponseHelper.getStatusCodeDescription(409), equals('Conflict'));
      expect(ResponseHelper.getStatusCodeDescription(418), equals("I'm a Teapot"));
      expect(ResponseHelper.getStatusCodeDescription(422), equals('Unprocessable Entity'));
      expect(ResponseHelper.getStatusCodeDescription(429), equals('Too Many Requests'));
    });

    test('returns correct descriptions for common 5xx codes', () {
      expect(ResponseHelper.getStatusCodeDescription(500), equals('Internal Server Error'));
      expect(ResponseHelper.getStatusCodeDescription(501), equals('Not Implemented'));
      expect(ResponseHelper.getStatusCodeDescription(502), equals('Bad Gateway'));
      expect(ResponseHelper.getStatusCodeDescription(503), equals('Service Unavailable'));
      expect(ResponseHelper.getStatusCodeDescription(504), equals('Gateway Timeout'));
    });

    test('returns generic "HTTP N" for unrecognized codes', () {
      expect(ResponseHelper.getStatusCodeDescription(143), equals('HTTP 143'));
      expect(ResponseHelper.getStatusCodeDescription(299), equals('HTTP 299'));
      expect(ResponseHelper.getStatusCodeDescription(499), equals('HTTP 499'));
      expect(ResponseHelper.getStatusCodeDescription(599), equals('HTTP 599'));
    });
  });
}