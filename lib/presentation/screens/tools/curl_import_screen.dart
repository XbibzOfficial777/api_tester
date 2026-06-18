/// @file curl_import_screen.dart
/// @brief Tool screen for importing API requests from cURL commands.
///
/// Provides a large text area for pasting a cURL command, an "Import" button
/// that parses it using the [CurlImport] use case, and a preview of the
/// parsed request (method, URL, headers, body) before the user confirms
/// adoption into the request builder.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/di/injection.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/api_request.dart';
import '../../../domain/usecases/import/curl_import.dart';
import '../../providers/request_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common/code_view.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Holds the parsed [ApiRequest] after a successful cURL import.
final parsedCurlRequestProvider = StateProvider<ApiRequest?>((ref) => null);

/// Whether the cURL import is currently parsing.
final isParsingCurlProvider = StateProvider<bool>((ref) => false);

/// Error message from the last cURL parse attempt.
final curlParseErrorProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Parses a pasted cURL command and creates a full API request from it.
///
/// The workflow:
/// 1. User pastes a cURL command into the text area.
/// 2. Taps "Import" → the [CurlImport] use case parses the command.
/// 3. A preview shows the parsed method, URL, headers, and body.
/// 4. User taps "Use This Request" to load it into the request builder.
class CurlImportScreen extends ConsumerStatefulWidget {
  /// Creates a [CurlImportScreen].
  const CurlImportScreen({super.key});

  @override
  ConsumerState<CurlImportScreen> createState() => _CurlImportScreenState();
}

class _CurlImportScreenState extends ConsumerState<CurlImportScreen> {
  final _curlController = TextEditingController();

  /// Example cURL command shown as placeholder text.
  static const _exampleCurl =
      "curl -X POST 'https://api.example.com/v1/users' \\\n"
      "  -H 'Content-Type: application/json' \\\n"
      "  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIs...' \\\n"
      "  -d '{\"name\": \"John Doe\", \"email\": \"john@example.com\"}'";

  @override
  void dispose() {
    _curlController.dispose();
    super.dispose();
  }

  /// Parses the pasted cURL command.
  Future<void> _import() async {
    final command = _curlController.text.trim();
    if (command.isEmpty) return;

    final workspaceId =
        ref.read(currentWorkspaceProvider)?.id ?? 'default-workspace';

    ref.read(isParsingCurlProvider.notifier).state = true;
    ref.read(curlParseErrorProvider.notifier).state = null;

    try {
      final useCase = CurlImport();
      final request = await useCase(CurlImportParams(
        curlCommand: command,
        workspaceId: workspaceId,
      ));
      ref.read(parsedCurlRequestProvider.notifier).state = request;
    } catch (e) {
      ref.read(curlParseErrorProvider.notifier).state =
          'Failed to parse cURL: $e';
    } finally {
      if (mounted) {
        ref.read(isParsingCurlProvider.notifier).state = false;
      }
    }
  }

  /// Loads the parsed request into the request builder form.
  void _useRequest() {
    final request = ref.read(parsedCurlRequestProvider);
    if (request == null) return;

    // Load into the request form state.
    ref.read(currentRequestProvider.notifier).loadFromRequest(request);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request loaded into builder'),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParsing = ref.watch(isParsingCurlProvider);
    final error = ref.watch(curlParseErrorProvider);
    final parsedRequest = ref.watch(parsedCurlRequestProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('cURL Import'),
        actions: [
          // Paste from clipboard button.
          IconButton(
            icon: const Icon(Symbols.content_paste, size: 20),
            tooltip: 'Paste from clipboard',
            onPressed: () async {
              final data =
                  await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null && data!.text!.isNotEmpty) {
                _curlController.text = data.text!;
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Description ---
            Text(
              'Paste a cURL command below to import it as an API request.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // --- cURL Input ---
            TextField(
              controller: _curlController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: _exampleCurl,
                labelText: 'cURL Command',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                prefixIcon:
                    const Icon(Symbols.terminal, size: 20),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),

            const SizedBox(height: 12),

            // --- Import Button ---
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isParsing ? null : _import,
                icon: isParsing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Symbols.download, size: 18),
                label: Text(isParsing ? 'Importing…' : 'Import'),
              ),
            ),

            // --- Error ---
            if (error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: colorScheme.error.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.error,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(error,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.error)),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // --- Parsed Request Preview ---
            if (parsedRequest != null) ...[
              const SizedBox(height: 24),
              Text('Parsed Request',
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // Method + URL
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(parsedRequest.method.name.toUpperCase(),
                              style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.primary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              parsedRequest.url,
                              style: textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Headers
              if (parsedRequest.headers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Headers',
                            style: textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...parsedRequest.headers.map((h) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  if (!h.isEnabled)
                                    Icon(Symbols.visibility_off,
                                        size: 14,
                                        color: colorScheme.outline),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: textTheme.bodySmall?.copyWith(
                                            fontFamily: 'monospace'),
                                        children: [
                                          TextSpan(
                                            text: h.key,
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const TextSpan(text: ': '),
                                          TextSpan(text: h.value),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],

              // Body
              if (parsedRequest.bodyContent.isNotEmpty) ...[
                const SizedBox(height: 8),
                CodeView(
                  code: parsedRequest.bodyContent,
                  language: CodeLanguage.json,
                  title: 'Request Body',
                  maxHeight: 200,
                ),
              ],

              // SSL info
              if (!parsedRequest.verifySsl) ...[
                const SizedBox(height: 8),
                Card(
                  color: AppTheme.status4xx.withOpacity(0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Symbols.warning,
                            color: AppTheme.status4xx, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'SSL verification is disabled (-k flag detected)',
                          style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.status4xx),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // --- Use This Request Button ---
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _useRequest,
                  icon: const Icon(Symbols.check, size: 18),
                  label: const Text('Use This Request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}