/// @file code_generator_screen.dart
/// @brief Tool screen for generating code snippets from API requests.
///
/// Accepts an optional [ApiRequest] (typically the current request being
/// built) and converts it into ready-to-use code for seven languages:
/// Dart, Python, JavaScript, Java, cURL, C#, and Go. The generated code
/// is displayed in a syntax-highlighted [CodeView] with copy and share
/// actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/injection.dart';
import '../../../domain/entities/api_request.dart';
import '../../../domain/usecases/tools/code_generator.dart';
import '../../providers/request_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../widgets/common/code_view.dart' hide CodeLanguage;
import '../../widgets/common/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Language Metadata
// ---------------------------------------------------------------------------

/// Metadata about a supported code generation language.
class _LanguageOption {
  /// The code generation language.
  final CodeLanguage language;

  /// Display name.
  final String label;

  /// Material Symbols icon for the language.
  final IconData icon;

  /// A short description / runtime info.
  final String description;

  const _LanguageOption({
    required this.language,
    required this.label,
    required this.icon,
    required this.description,
  });
}

/// All supported language options with their icons and descriptions.
const _kLanguages = [
  _LanguageOption(
    language: CodeLanguage.dart,
    label: 'Dart',
    icon: Symbols.flutter_dash,
    description: 'http package',
  ),
  _LanguageOption(
    language: CodeLanguage.python,
    label: 'Python',
    icon: Symbols.code,
    description: 'requests library',
  ),
  _LanguageOption(
    language: CodeLanguage.javascript,
    label: 'JavaScript',
    icon: Symbols.javascript,
    description: 'Fetch API',
  ),
  _LanguageOption(
    language: CodeLanguage.java,
    label: 'Java',
    icon: Symbols.coffee,
    description: 'HttpURLConnection',
  ),
  _LanguageOption(
    language: CodeLanguage.curl,
    label: 'cURL',
    icon: Symbols.terminal,
    description: 'Command line',
  ),
  _LanguageOption(
    language: CodeLanguage.csharp,
    label: 'C#',
    icon: Symbols.data_object,
    description: 'HttpClient',
  ),
  _LanguageOption(
    language: CodeLanguage.go,
    label: 'Go',
    icon: Symbols.webhook,
    description: 'net/http',
  ),
];

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Holds the currently selected language for code generation.
final selectedCodeLanguageProvider =
    StateProvider<CodeLanguage>((ref) => CodeLanguage.curl);

/// Holds the generated code string, or null if not yet generated.
final generatedCodeProvider = StateProvider<String?>((ref) => null);

/// Whether code generation is in progress.
final isGeneratingCodeProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Converts an API request into code in various languages.
///
/// If [request] is provided, that request is used. Otherwise the screen
/// reads the current [currentRequestProvider] to get the request being
/// built in the request builder.
class CodeGeneratorScreen extends ConsumerStatefulWidget {
  /// Optional pre-populated request. When null, reads from the provider.
  final ApiRequest? request;

  /// Creates a [CodeGeneratorScreen].
  const CodeGeneratorScreen({super.key, this.request});

  @override
  ConsumerState<CodeGeneratorScreen> createState() =>
      _CodeGeneratorScreenState();
}

class _CodeGeneratorScreenState extends ConsumerState<CodeGeneratorScreen> {
  final _uuid = const Uuid();

  /// Builds an [ApiRequest] from the current form state or the constructor
  /// parameter, for use in code generation.
  ApiRequest? _buildRequest() {
    if (widget.request != null) return widget.request;
    final form = ref.read(currentRequestProvider);
    if (form.url.trim().isEmpty) return null;

    final workspaceId = ref.read(currentWorkspaceProvider)?.id ?? '';
    final now = DateTime.now();

    return ApiRequest(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      name: 'Generated',
      method: form.method,
      url: form.url.trim(),
      headers: form.headers,
      queryParams: form.queryParams,
      bodyType: form.bodyType,
      bodyContent: form.bodyContent,
      formDataItems: form.formDataItems,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Generates code for the currently selected language.
  Future<void> _generateCode() async {
    final request = _buildRequest();
    if (request == null) return;

    final language = ref.read(selectedCodeLanguageProvider);
    ref.read(isGeneratingCodeProvider.notifier).state = true;

    try {
      final generator = CodeGenerator();
      final code = await generator(CodeGeneratorParams(
        request: request,
        language: language,
      ));
      ref.read(generatedCodeProvider.notifier).state = code;
    } catch (e) {
      ref.read(generatedCodeProvider.notifier).state =
          '// Error generating code:\n// $e';
    } finally {
      if (mounted) {
        ref.read(isGeneratingCodeProvider.notifier).state = false;
      }
    }
  }

  /// Copies the generated code to the clipboard.
  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Code copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Shares the generated code via the system share sheet.
  void _shareCode(String code) {
    final lang = ref.read(selectedCodeLanguageProvider);
    Share.share(code, subject: 'API Request Code (${lang.name})');
  }

  @override
  Widget build(BuildContext context) {
    final selectedLang = ref.watch(selectedCodeLanguageProvider);
    final generatedCode = ref.watch(generatedCodeProvider);
    final isGenerating = ref.watch(isGeneratingCodeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Auto-generate when language changes if we already have code.
    ref.listen<CodeLanguage>(selectedCodeLanguageProvider, (prev, next) {
      if (prev != next && ref.read(generatedCodeProvider) != null) {
        _generateCode();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Generator'),
        actions: [
          if (generatedCode != null) ...[
            IconButton(
              icon: const Icon(Symbols.share, size: 20),
              tooltip: 'Share',
              onPressed: () => _shareCode(generatedCode!),
            ),
            IconButton(
              icon: const Icon(Symbols.copy_all, size: 20),
              tooltip: 'Copy',
              onPressed: () => _copyCode(generatedCode!),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // --- Language Selector ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target Language',
                    style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _kLanguages.map((lang) {
                      final isSelected = lang.language == selectedLang;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(lang.icon,
                              size: 16,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface),
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(lang.label,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  )),
                              Text(lang.description,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? colorScheme.onPrimary.withOpacity(0.8)
                                        : colorScheme.onSurfaceVariant,
                                  )),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            ref
                                .read(selectedCodeLanguageProvider.notifier)
                                .state = lang.language;
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- Request Summary ---
          Builder(builder: (context) {
            final request = _buildRequest();
            if (request == null) {
              return Expanded(
                child: EmptyStateWidget(
                  icon: Symbols.code,
                  title: 'No Request to Generate',
                  subtitle:
                      'Build a request in the request builder first, then open the code generator.',
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      request.method.name.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.url,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // --- Generate Button ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isGenerating ? null : _generateCode,
                icon: isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Symbols.auto_awesome, size: 18),
                label: Text(
                    isGenerating ? 'Generating…' : 'Generate Code'),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // --- Generated Code Display ---
          if (generatedCode != null)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CodeView(
                  code: generatedCode,
                  language: CodeLanguage.plainText,
                  title: '${selectedLang.name.toUpperCase()} Code',
                  maxHeight: double.infinity,
                ),
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Select a language and generate code.',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}