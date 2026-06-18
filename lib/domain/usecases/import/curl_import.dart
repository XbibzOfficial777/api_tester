/// @file curl_import.dart
/// @brief Use case for importing an API request from a curl command string.
///
/// Parses common curl command syntax and extracts the HTTP method, URL,
/// headers, body, and form data into an [ApiRequest] entity.
///
/// Supports:
/// - Explicit methods: -X, --request
/// - Headers: -H, --header
/// - Data: -d, --data, --data-raw, --data-binary, --data-urlencode
/// - URL-encoded form data (when Content-Type is application/x-www-form-urlencoded)
/// - Basic auth: -u, --user
/// - Bearer token: -H "Authorization: Bearer ..."
/// - Insecure flag: -k, --insecure
/// - Silent mode: -s, --silent (ignored)
/// - Location/redirects: -L, --location (ignored, as we have our own setting)
/// - Cookie: --cookie, -b
library;

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../entities/api_request.dart';
import '../../entities/form_data_item.dart';
import '../../entities/key_value_item.dart';
import '../usecase.dart';

/// Parameters for the cURL import use case.
class CurlImportParams {
  /// The raw curl command string to parse.
  final String curlCommand;

  /// The workspace ID to assign to the imported request.
  final String workspaceId;

  /// An optional collection ID to assign to the imported request.
  final String? collectionId;

  /// Creates parameter object for cURL import.
  ///
  /// [curlCommand] - The complete curl command as a string.
  /// [workspaceId] - The target workspace ID.
  /// [collectionId] - Optional collection ID.
  const CurlImportParams({
    required this.curlCommand,
    required this.workspaceId,
    this.collectionId,
  });
}

/// Parses a curl command string and produces an [ApiRequest].
///
/// Uses regex-based tokenization to handle the various flags and
/// quoting styles that curl supports. Produces a fully configured
/// request entity ready for editing or execution.
class CurlImport extends UseCase<ApiRequest, CurlImportParams> {
  /// UUID generator for creating request and item IDs.
  static const _uuid = Uuid();

  /// Creates a new [CurlImport] use case.
  CurlImport();

  /// Parses the curl command and returns an [ApiRequest].
  @override
  Future<ApiRequest> call(CurlImportParams params) async {
    final curl = params.curlCommand.trim();

    // Tokenize the curl command into a list of arguments, respecting quotes.
    final tokens = _tokenize(curl);

    // Remove the "curl" prefix if present.
    final args = tokens.skipWhile((t) => t == 'curl').toList();

    var method = HttpMethod.get;
    String? url;
    final headers = <KeyValueItem>[];
    var bodyType = BodyType.none;
    var bodyContent = '';
    var verifySsl = true;
    var hasData = false;

    // Iterate through arguments, consuming flags and their values.
    var i = 0;
    while (i < args.length) {
      final arg = args[i];

      // Explicit HTTP method.
      if (arg == '-X' || arg == '--request') {
        i++;
        if (i < args.length) {
          method = _parseMethod(args[i]);
        }
      }
      // Headers.
      else if (arg == '-H' || arg == '--header') {
        i++;
        if (i < args.length) {
          final header = _parseHeader(args[i]);
          if (header != null) {
            headers.add(header);
          }
        }
      }
      // Data flags (multiple variants).
      else if (arg == '-d' ||
          arg == '--data' ||
          arg == '--data-raw' ||
          arg == '--data-binary' ||
          arg == '--data-urlencode') {
        i++;
        if (i < args.length) {
          hasData = true;
          if (arg == '--data-urlencode') {
            // Handle @file syntax: --data-urlencode name@file.txt
            final dataArg = args[i];
            if (dataArg.contains('@')) {
              final parts = dataArg.split('@');
              if (parts.length == 2) {
                // This is a file reference; store the key.
                bodyContent = '${parts[0]}=@${parts[1]}';
              } else {
                bodyContent = dataArg;
              }
            } else {
              bodyContent = dataArg;
            }
          } else {
            bodyContent = args[i];
          }
        }
      }
      // Basic authentication.
      else if (arg == '-u' || arg == '--user') {
        i++;
        if (i < args.length) {
          final credentials = args[i];
          // Remove any existing Authorization header.
          headers.removeWhere(
            (h) => h.key.toLowerCase() == 'authorization',
          );
          // curl -u user:pass sends as Base64 of "user:pass".
          final encoded = _base64Encode(credentials);
          headers.add(KeyValueItem(
            key: 'Authorization',
            value: 'Basic $encoded',
            isEnabled: true,
            id: _uuid.v4(),
          ));
        }
      }
      // Insecure / skip SSL verification.
      else if (arg == '-k' || arg == '--insecure') {
        verifySsl = false;
      }
      // Cookie.
      else if (arg == '-b' || arg == '--cookie') {
        i++;
        if (i < args.length) {
          headers.removeWhere(
            (h) => h.key.toLowerCase() == 'cookie',
          );
          headers.add(KeyValueItem(
            key: 'Cookie',
            value: args[i],
            isEnabled: true,
            id: _uuid.v4(),
          ));
        }
      }
      // Flags without values that we can ignore.
      else if (arg == '-s' ||
          arg == '--silent' ||
          arg == '-S' ||
          arg == '-L' ||
          arg == '--location' ||
          arg == '-v' ||
          arg == '--verbose' ||
          arg == '-i' ||
          arg == '--include' ||
          arg == '-g' ||
          arg == '--globoff' ||
          arg == '--compressed') {
        // Intentionally ignored flags.
      }
      // Compressed short flags (e.g., -sS, -sSL).
      else if (arg.startsWith('-') && !arg.startsWith('--') && arg.length > 2) {
        // Handle combined short flags like -sSL or -XPOST.
        final flagChars = arg.substring(1);
        for (var c = 0; c < flagChars.length; c++) {
          final ch = flagChars[c];
          if (ch == 'k') {
            verifySsl = false;
          }
          // Other single-char flags are ignored.
        }
      }
      // Assume this is the URL if it starts with http:// or https://
      // or if it looks like a hostname.
      else if (url == null &&
          (arg.startsWith('http://') ||
              arg.startsWith('https://') ||
              arg.startsWith("'http://") ||
              arg.startsWith("'https://"))) {
        url = arg;
      } else if (url == null &&
          !arg.startsWith('-') &&
          _looksLikeUrl(arg)) {
        url = arg;
      }

      i++;
    }

    // Default URL if none was found.
    url ??= 'https://example.com';

    // Clean up the URL (remove surrounding quotes if present).
    url = _stripQuotes(url);

    // Determine body type and content.
    List<FormDataItem> formDataItems = [];
    if (hasData && bodyContent.isNotEmpty) {
      final isUrlEncoded = headers.any(
        (h) =>
            h.key.toLowerCase() == 'content-type' &&
            h.value.toLowerCase().contains('application/x-www-form-urlencoded'),
      );

      if (isUrlEncoded) {
        bodyType = BodyType.urlEncoded;
        formDataItems = _parseUrlEncodedBody(bodyContent);
      } else {
        bodyType = BodyType.raw;
      }
    }

    // If there's data but no explicit Content-Type, default to application/json
    // if the body looks like JSON.
    if (hasData &&
        bodyType == BodyType.raw &&
        !headers.any((h) => h.key.toLowerCase() == 'content-type')) {
      final trimmed = bodyContent.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        headers.add(KeyValueItem(
          key: 'Content-Type',
          value: 'application/json',
          isEnabled: true,
          id: _uuid.v4(),
        ));
      }
    }

    // Generate a name from the URL path.
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final name = path.isEmpty
        ? method.name.toUpperCase()
        : '${method.name.toUpperCase()} $path';

    final now = DateTime.now();

    return ApiRequest(
      id: _uuid.v4(),
      workspaceId: params.workspaceId,
      collectionId: params.collectionId,
      name: name,
      description: 'Imported from curl command',
      method: method,
      url: url,
      headers: headers,
      queryParams: [],
      bodyType: bodyType,
      bodyContent: bodyContent,
      formDataItems: formDataItems,
      verifySsl: verifySsl,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Tokenizes a curl command string into individual arguments.
  ///
  /// Handles single quotes, double quotes, and escaped quotes within
  /// arguments. Handles the $'...' ANSI-C quoting syntax.
  List<String> _tokenize(String command) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var i = 0;

    while (i < command.length) {
      final char = command[i];

      if (inSingleQuote) {
        if (char == "'" && (i + 1 >= command.length || command[i + 1] != "'")) {
          inSingleQuote = false;
        } else if (char == "'" && i + 1 < command.length && command[i + 1] == "'") {
          // Escaped single quote inside single quotes ('').
          buffer.write("'");
          i++; // Skip the second quote.
        } else {
          buffer.write(char);
        }
      } else if (inDoubleQuote) {
        if (char == '\\' && i + 1 < command.length) {
          // Handle escape sequences inside double quotes.
          final next = command[i + 1];
          if (next == '"' || next == '\\' || next == '\$' || next == '`') {
            buffer.write(next);
            i++;
          } else {
            buffer.write(char);
            buffer.write(next);
            i++;
          }
        } else if (char == '"') {
          inDoubleQuote = false;
        } else {
          buffer.write(char);
        }
      } else {
        // Not in quotes.
        if (char == "'") {
          inSingleQuote = true;
        } else if (char == '"') {
          inDoubleQuote = true;
        } else if (char == '\\' && i + 1 < command.length) {
          // Handle escaped space or other character outside quotes.
          buffer.write(command[i + 1]);
          i++;
        } else if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
          if (buffer.isNotEmpty) {
            tokens.add(buffer.toString());
            buffer.clear();
          }
        } else {
          buffer.write(char);
        }
      }

      i++;
    }

    // Don't forget the last token.
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }

  /// Parses a header string ("Key: Value") into a [KeyValueItem].
  ///
  /// Returns null if the header string is malformed (no colon separator).
  KeyValueItem? _parseHeader(String header) {
    // Find the first colon that separates the key from the value.
    final colonIndex = header.indexOf(':');
    if (colonIndex < 0) return null;

    final key = header.substring(0, colonIndex).trim();
    final value = header.substring(colonIndex + 1).trim();

    if (key.isEmpty) return null;

    return KeyValueItem(
      key: key,
      value: value,
      isEnabled: true,
      id: _uuid.v4(),
    );
  }

  /// Parses a method string into the [HttpMethod] enum.
  ///
  /// Handles both uppercase and lowercase method names.
  HttpMethod _parseMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.get;
      case 'POST':
        return HttpMethod.post;
      case 'PUT':
        return HttpMethod.put;
      case 'PATCH':
        return HttpMethod.patch;
      case 'DELETE':
        return HttpMethod.delete;
      case 'HEAD':
        return HttpMethod.head;
      case 'OPTIONS':
        return HttpMethod.options;
      default:
        return HttpMethod.get;
    }
  }

  /// Parses a URL-encoded body string into a list of [FormDataItem].
  ///
  /// Handles both simple key=value and key=@value (file reference) formats.
  List<FormDataItem> _parseUrlEncodedBody(String body) {
    final items = <FormDataItem>[];
    final pairs = body.split('&');

    for (final pair in pairs) {
      final eqIndex = pair.indexOf('=');
      if (eqIndex < 0) continue;

      final key = Uri.decodeComponent(pair.substring(0, eqIndex));
      final value = Uri.decodeComponent(pair.substring(eqIndex + 1));

      final isFile = value.startsWith('@');

      items.add(FormDataItem(
        key: key,
        value: isFile ? value.substring(1) : value,
        isFile: isFile,
        filePath: isFile ? value.substring(1) : '',
        fileName: isFile ? value.substring(1).split('/').last : '',
        contentType: '',
        id: _uuid.v4(),
      ));
    }

    return items;
  }

  /// Checks if a string looks like a URL (has a scheme or contains a dot and slash).
  bool _looksLikeUrl(String str) {
    return str.contains('://') ||
        (str.contains('.') && str.contains('/')) ||
        str.contains('.');
  }

  /// Strips surrounding quotes from a string.
  ///
  /// Handles both single and double quotes, as well as ANSI-C $'...' quoting.
  String _stripQuotes(String input) {
    if (input.length < 2) return input;

    if ((input.startsWith("'") && input.endsWith("'")) ||
        (input.startsWith('"') && input.endsWith('"'))) {
      return input.substring(1, input.length - 1);
    }

    // Handle $'...' ANSI-C quoting.
    if (input.startsWith("\$'") && input.endsWith("'")) {
      return input.substring(2, input.length - 1);
    }

    return input;
  }

  /// Base64-encodes a string using Dart's built-in codec.
  ///
  /// Used for Basic authentication encoding (user:password).
  String _base64Encode(String input) {
    return base64Encode(input.codeUnits);
  }
}