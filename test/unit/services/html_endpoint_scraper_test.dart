import 'package:test/test.dart';
import 'package:api_tester/core/services/html_endpoint_scraper.dart';

void main() {
  const baseUrl = 'https://example.com';

  group('HtmlEndpointScraper', () {
    group('/api/v1/... URLs', () {
      test('discovers /api/v1/ URLs in HTML text', () {
        final html = '''
          <html>
            <body>
              <a href="/api/v1/users">Users</a>
              <script>fetch("/api/v1/products")</script>
            </body>
          </html>
        ''';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(urls.any((u) => u.contains('/api/v1/users')), isTrue);
      });
    });

    group('/rest/... URLs', () {
      test('discovers /rest/ URLs', () {
        final html = '''
          <html>
            <body>
              <a href="/rest/orders">Orders</a>
            </body>
          </html>
        ''';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(urls.any((u) => u.contains('/rest/orders')), isTrue);
      });
    });

    group('.json/.xml file references', () {
      test('discovers URLs ending in .json', () {
        final html = '''
          <html>
            <body>
              <a href="/data/config.json">Config</a>
            </body>
          </html>
        ''';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(urls.any((u) => u.endsWith('.json')), isTrue);
      });

      test('discovers URLs ending in .xml', () {
        final html = '''
          <html>
            <body>
              <a href="/feed/rss.xml">RSS Feed</a>
            </body>
          </html>
        ''';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(urls.any((u) => u.endsWith('.xml')), isTrue);
      });
    });

    group('href attributes', () {
      test('extracts URLs from href attributes', () {
        final html = '''
          <html>
            <body>
              <a href="/api/v1/items">Items</a>
              <link rel="stylesheet" href="/style.css">
            </body>
          </html>
        ''';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        final urls = endpoints.map((e) => e.url).toList();
        // /api/v1/items should be found; /style.css should NOT (not an API).
        expect(urls.any((u) => u.contains('/api/v1/items')), isTrue);
        expect(urls.any((u) => u.contains('/style.css')), isFalse);
      });
    });

    group('deduplication', () {
      test('does not return duplicate URLs', () {
        final html = '''
          <html>
            <body>
              <a href="/api/v1/users">First</a>
              <a href="/api/v1/users">Second</a>
              <a href="/api/v1/users">Third</a>
            </body>
          </html>
        ''';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(urls.where((u) => u.contains('/api/v1/users')).length, equals(1));
      });
    });

    group('relative URL resolution', () {
      test('resolves relative URLs against the base URL', () {
        final html = '<a href="/api/v1/data">Data</a>';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: 'https://example.com',
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(
          urls.any((u) => u == 'https://example.com/api/v1/data'),
          isTrue,
        );
      });

      test('resolves relative path URLs against base with path', () {
        final html = '<a href="/api/v1/test">Test</a>';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: 'https://example.com/app',
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(
          urls.any((u) => u == 'https://example.com/api/v1/test'),
          isTrue,
        );
      });

      test('keeps absolute URLs as-is', () {
        final html = '<a href="https://other.com/api/v1/data">External</a>';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: 'https://example.com',
        );

        final urls = endpoints.map((e) => e.url).toList();
        expect(
          urls.any((u) => u == 'https://other.com/api/v1/data'),
          isTrue,
        );
      });
    });

    group('empty HTML', () {
      test('returns empty list for empty HTML', () {
        final endpoints = HtmlEndpointScraper.scrape(
          html: '',
          baseUrl: baseUrl,
        );

        expect(endpoints, isEmpty);
      });

      test('returns empty list for HTML with no API URLs', () {
        final html = '<html><body><p>Hello, World!</p></body></html>';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        expect(endpoints, isEmpty);
      });
    });

    group('invalid base URL', () {
      test('returns empty list for invalid base URL', () {
        final endpoints = HtmlEndpointScraper.scrape(
          html: '<a href="/api/v1/test">Test</a>',
          baseUrl: 'not-a-url',
        );

        expect(endpoints, isEmpty);
      });
    });

    group('default method', () {
      test('all discovered endpoints default to GET method', () {
        final html = '<a href="/api/v1/users">Users</a>';

        final endpoints = HtmlEndpointScraper.scrape(
          html: html,
          baseUrl: baseUrl,
        );

        expect(endpoints, isNotEmpty);
        for (final endpoint in endpoints) {
          expect(endpoint.method, equals('GET'));
        }
      });
    });
  });
}