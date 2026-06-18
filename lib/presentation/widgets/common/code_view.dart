/// @file code_view.dart
/// @brief Syntax-highlighted code display widget with line numbers,
/// copy-to-clipboard, and collapsible body.
///
/// Supports JSON, XML, and HTML highlighting via the `flutter_highlight`
/// package. Falls back to plain-text display for unsupported languages.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/atom-one-light.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

/// Supported syntax-highlighting languages.
enum CodeLanguage {
  /// JavaScript Object Notation.
  json,

  /// eXtensible Markup Language.
  xml,

  /// HyperText Markup Language.
  html,

  /// Plain text — no highlighting.
  plainText,
}

/// A code display widget with syntax highlighting, line numbers, a copy
/// button, and a collapsible body.
///
/// Example:
/// ```dart
/// CodeView(
///   code: jsonEncode(responseBody),
///   language: CodeLanguage.json,
///   title: 'Response Body',
/// )
/// ```
class CodeView extends StatefulWidget {
  /// The source code string to display.
  final String code;

  /// The language for syntax highlighting.
  final CodeLanguage language;

  /// Optional title displayed above the code block.
  final String? title;

  /// Whether the code block starts collapsed. Defaults to `false`.
  final bool initiallyCollapsed;

  /// Maximum height when expanded. When the code exceeds this height
  /// the view becomes scrollable. Defaults to `400`.
  final double maxHeight;

  /// Font size for the code text. Defaults to `13`.
  final double fontSize;

  /// Whether to show line numbers. Defaults to `true`.
  final bool showLineNumbers;

  /// Creates a [CodeView].
  const CodeView({
    super.key,
    required this.code,
    this.language = CodeLanguage.json,
    this.title,
    this.initiallyCollapsed = false,
    this.maxHeight = 400,
    this.fontSize = 13,
    this.showLineNumbers = true,
  });

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  late bool _isCollapsed;
  bool _copied = false;

  /// Map of [CodeLanguage] to highlight.js language keys.
  static const _langMap = <CodeLanguage, String>{
    CodeLanguage.json: 'json',
    CodeLanguage.xml: 'xml',
    CodeLanguage.html: 'html',
    CodeLanguage.plainText: 'plaintext',
  };

  @override
  void initState() {
    super.initState();
    _isCollapsed = widget.initiallyCollapsed;
  }

  @override
  void didUpdateWidget(covariant CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _copied = false;
    }
  }

  /// Copies [widget.code] to the system clipboard and shows feedback.
  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    // Reset the "copied" state after a short delay.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  /// Formats the code with indentation.
  String _formatCode() {
    // For JSON, try to pretty-print it.
    if (widget.language == CodeLanguage.json) {
      try {
        final decoded = jsonDecode(widget.code);
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(decoded);
      } catch (_) {
        // Fall through to raw code.
      }
    }
    return widget.code;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedCode = _formatCode();
    final lineCount = '\n'.allMatches(formattedCode).length + 1;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar: title, language badge, copy button, collapse toggle.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: isDark
                ? const Color(0xFF282C34)
                : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              children: [
                // Title.
                if (widget.title != null)
                  Expanded(
                    child: Text(
                      widget.title!,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFABB2BF)
                                : colorScheme.onSurface,
                          ),
                    ),
                  )
                else
                  const Spacer(),

                // Language badge.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _langMap[widget.language]!.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          fontSize: 10,
                        ),
                  ),
                ),
                const SizedBox(width: 8),

                // Copy button.
                IconButton(
                  icon: Icon(
                    _copied ? Symbols.check : Symbols.copy_all,
                    size: 18,
                    color: _copied
                        ? colorScheme.secondary
                        : isDark
                            ? const Color(0xFFABB2BF)
                            : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _copied ? 'Copied!' : 'Copy to clipboard',
                  onPressed: _copyToClipboard,
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),

                // Collapse toggle.
                IconButton(
                  icon: Icon(
                    _isCollapsed
                        ? Symbols.expand_more
                        : Symbols.expand_less,
                    size: 18,
                    color: isDark
                        ? const Color(0xFFABB2BF)
                        : colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _isCollapsed ? 'Expand' : 'Collapse',
                  onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // Code body.
          if (!_isCollapsed)
            ClipRect(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: _buildCodeBody(
                  formattedCode,
                  lineCount,
                  isDark,
                  colorScheme,
                ),
              ),
            )
                .animate(target: _isCollapsed ? 0 : 1)
                .scale(duration: 250.ms, curve: Curves.easeInOut),
        ],
      ),
    );
  }

  /// Builds the syntax-highlighted code area with optional line numbers.
  Widget _buildCodeBody(
    String code,
    int lineCount,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line numbers column.
          if (widget.showLineNumbers)
            Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: isDark
                  ? const Color(0xFF21252B)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: SingleChildScrollView(
                controller: ScrollController(), // Will sync with main scroll.
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: List.generate(
                    lineCount,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: widget.fontSize - 1,
                          fontFamily: 'monospace',
                          color: isDark
                              ? const Color(0xFF5C6370)
                              : colorScheme.onSurfaceVariant.withOpacity(0.5),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Code area.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: _buildHighlightView(code, isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the highlight.js-powered code view.
  Widget _buildHighlightView(String code, bool isDark) {
    // Use the highlight package for supported languages.
    if (widget.language != CodeLanguage.plainText && code.isNotEmpty) {
      try {
        return HighlightView(
          code,
          language: _langMap[widget.language]!,
          theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
          textStyle: TextStyle(
            fontSize: widget.fontSize,
            fontFamily: 'monospace',
            height: 1.6,
          ),
        );
      } catch (_) {
        // Fall through to plain text.
      }
    }

    // Fallback: plain text display.
    return SelectableText(
      code,
      style: TextStyle(
        fontSize: widget.fontSize,
        fontFamily: 'monospace',
        height: 1.6,
        color: isDark ? const Color(0xFFABB2BF) : null,
      ),
    );
  }
}

