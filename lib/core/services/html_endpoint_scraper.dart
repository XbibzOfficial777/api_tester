/// @file html_endpoint_scraper.dart
/// @brief Simple HTML endpoint scraper using regex-based extraction.
///
/// Analyses raw HTML content to discover API endpoints that are referenced
/// in the page. This is useful for quickly populating an API tester
/// workspace from a website's frontend code.
///
/// **Detection strategies:**
/// 1. **Pattern matching** — scans the entire HTML for URL-like strings
///    that match common API path conventions:
///    - `/api/v1/...`, `/api/v2/...`
///    - `/rest/...`
///    - `/graphql`
///    - URLs ending in `.json`, `.xml`
/// 2. **Attribute extraction** — finds URLs in HTML attributes:
///    - `href="..."`, `src="..."`, `action="..."`, `data-url="..."`,
///      `data-api="..."`, `data-endpoint="..."`.
///
/// **Output:**
/// Returns a deduplicated list of [DiscoveredEndpoint] objects, each
/// containing a URL and a default HTTP method (always `"GET"` since
/// HTML alone cannot reliably determine the method).
///
/// **Limitations:**
/// - JavaScript-generated URLs (dynamic SPAs) are not captured.
/// - Only absolute or root-relative URLs are resolved using the [baseUrl].
/// - This is a best-effort scraper, not a full HTML parser.

library;

/// A discovered API endpoint extracted from HTML content.
///
/// Contains the resolved URL and a default HTTP method. Since HTML does
/// not convey the HTTP method (except for `<form method="...">` which
/// would require a full HTML parser), all endpoints default to `GET`.
///
/// Use the URL and method to pre-populate the API Tester's request form.
class DiscoveredEndpoint {
  /// Creates a new [DiscoveredEndpoint].
  const DiscoveredEndpoint({
    required this.url,
    this.method = 'GET',
  });

  /// The fully resolved endpoint URL.
  ///
  /// Relative URLs are resolved against the base URL provided to
  /// [HtmlEndpointScraper.scrape].
  final String url;

  /// The HTTP method for this endpoint.
  ///
  /// Defaults to `"GET"` since HTML alone cannot determine the method.
  /// Callers may override this based on context (e.g. if the URL was
  /// found in a `<form method="POST">`).
  final String method;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredEndpoint &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          method == other.method;

  @override
  int get hashCode => url.hashCode ^ method.hashCode;

  @override
  String toString() => 'DiscoveredEndpoint($method $url)';
}

/// Scrapes HTML content to discover API endpoint URLs.
///
/// Uses regular expressions to find URLs matching common API patterns
/// and URLs embedded in HTML attributes. All results are deduplicated
/// and resolved against a provided [baseUrl].
///
/// Example:
/// ```dart
/// final html = '<a href="/api/v1/users">Users</a>';
/// final endpoints = HtmlEndpointScraper.scrape(
///   html: html,
///   baseUrl: 'https://example.com',
/// );
/// // endpoints → [DiscoveredEndpoint(url: 'https://example.com/api/v1/users')]
/// ```
class HtmlEndpointScraper {
  HtmlEndpointScraper._();

  // ---------------------------------------------------------------------------
  // Regex patterns
  // ---------------------------------------------------------------------------

  /// Matches common API path patterns in HTML/JS text.
  ///
  /// Captures:
  /// - `/api/v\d+/...`
  /// - `/rest/...`
  /// - `/graphql`
  /// - URLs ending in `.json` or `.xml`
  ///
  /// The pattern looks for these paths as standalone tokens (preceded by
  /// a quote, whitespace, or `=` and followed by a quote, whitespace,
  /// `)`, `}`, `,`, or `?`).
  static final RegExp _apiPathPattern = RegExp(
    r'''(?:"|'|\s|=|url\(|href=|src=|action=|data-url=|data-api=|data-endpoint=)['"\s]*?)(/?(?:api/v\d+|rest|graphql)[/\w\-._~:/?#\[\]@!$&'()*+,;=%]*?(?:\.json|\.xml)?)(?=["'\s)}\],?]|$)''',
    caseSensitive: false,
  );

  /// Matches URLs in common HTML attributes.
  ///
  /// Captures the value of `href`, `src`, `action`, and `data-*` URL
  /// attributes.
  static final RegExp _attributePattern = RegExp(
    r'''(?:href|src|action|data-url|data-api|data-endpoint|data-base-url)\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// Matches URLs that look like API endpoints within attribute values
  /// (e.g. paths containing "api", "rest", "graphql", or ending in
  /// `.json`/`.xml`).
  static final RegExp _endpointInUrlPattern = RegExp(
    r'''(?:/api/|/rest/|/graphql|\.json\b|\.xml\b)''',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Scrapes [html] content for API endpoint URLs.
  ///
  /// [html] — The raw HTML source as a string.
  /// [baseUrl] — The base URL used to resolve relative URLs. Must include
  /// the scheme and host (e.g. `"https://example.com"`).
  ///
  /// Returns a deduplicated list of [DiscoveredEndpoint] objects.
  /// Each endpoint defaults to the `GET` method.
  ///
  /// The method is O(n) where n is the length of the HTML string.
  static List<DiscoveredEndpoint> scrape({
    required String html,
    required String baseUrl,
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null) {
      // Invalid base URL — return empty list.
      return [];
    }

    final foundUrls = <String>{};

    // --- Strategy 1: Pattern matching for API paths ---
    for (final match in _apiPathPattern.allMatches(html)) {
      final path = match.group(1);
      if (path != null && path.isNotEmpty) {
        final resolved = _resolveUrl(uri, path);
        if (resolved != null) {
          foundUrls.add(resolved);
        }
      }
    }

    // --- Strategy 2: Attribute extraction ---
    for (final match in _attributePattern.allMatches(html)) {
      final rawUrl = match.group(1);
      if (rawUrl == null || rawUrl.isEmpty) continue;

      // Filter: only keep URLs that look like API endpoints.
      if (!_endpointInUrlPattern.hasMatch(rawUrl)) continue;

      final resolved = _resolveUrl(uri, rawUrl);
      if (resolved != null) {
        foundUrls.add(resolved);
      }
    }

    // Convert to DiscoveredEndpoint list, deduplicated.
    return foundUrls
        .map((url) => DiscoveredEndpoint(url: url))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // URL resolution
  // ---------------------------------------------------------------------------

  /// Resolves a [path] against the [baseUri].
  ///
  /// Handles:
  /// - Absolute URLs (`https://...`) — returned as-is.
  /// - Protocol-relative URLs (`//example.com/...`) — scheme is added
  ///   from the base.
  /// - Root-relative URLs (`/api/...`) — scheme + authority prepended.
  /// - Relative URLs (`api/...`) — resolved relative to the base path.
  ///
  /// Returns `null` if the resulting URL is invalid.
  static String? _resolveUrl(Uri baseUri, String path) {
    try {
      // Already absolute?
      if (path.startsWith('http://') || path.startsWith('https://')) {
        final parsed = Uri.parse(path);
        return parsed.toString();
      }

      // Protocol-relative?
      if (path.startsWith('//')) {
        return '${baseUri.scheme}:$path';
      }

      // Use Uri.resolve for relative / root-relative paths.
      final resolved = baseUri.resolve(path);
      return resolved.toString();
    } catch (_) {
      return null;
    }
  }
}