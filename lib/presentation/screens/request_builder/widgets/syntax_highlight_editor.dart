/// @file syntax_highlight_editor.dart
/// @brief A code editor with real-time syntax highlighting, line numbers,
///        and validation for JSON and XML.
///
/// Provides an inline code-editing experience using a stacked [TextField]
/// and a semi-transparent highlighted overlay. For JSON, it validates the
/// content in real-time and shows a green checkmark or red cross with an
/// error message (including approximate line/column). For XML, it performs
/// basic well-formedness checking.

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

// ---------------------------------------------------------------------------
// Syntax Highlight Theme
// ---------------------------------------------------------------------------

/// Token colours used for syntax highlighting.
class SyntaxColors {
  const SyntaxColors._();

  /// Colour for string tokens.
  static const Color string = Color(0xFF98C379);

  /// Colour for number tokens.
  static const Color number = Color(0xFFD19A66);

  /// Colour for boolean / null tokens.
  static const Color boolean = Color(0xFFC678DD);

  /// Colour for JSON / XML keys.
  static const Color key = Color(0xFFE06C75);

  /// Colour for punctuation and brackets.
  static const Color punctuation = Color(0xFFABB2BF);

  /// Colour for tag names in XML.
  static const Color tagName = Color(0xFFE06C75);

  /// Colour for attribute values in XML.
  static const Color attribute = Color(0xFFD19A66);
}

// ---------------------------------------------------------------------------
// Highlighted TextSpan Builder
// ---------------------------------------------------------------------------

/// Result of validating code content.
class ValidationResult {
  /// Whether the content is valid.
  final bool isValid;

  /// Human-readable error message, or `null` when valid.
  final String? errorMessage;

  /// Approximate line number of the error (1-based), or `null`.
  final int? errorLine;

  /// Approximate column number of the error (1-based), or `null`.
  final int? errorColumn;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorLine,
    this.errorColumn,
  });
}

/// Builds a list of [TextSpan]s that colourise [source] for the given
/// [language] ("json" or "xml").
List<TextSpan> highlightSyntax(String source, String language) {
  if (source.isEmpty) return [const TextSpan(text: '')];

  if (language == 'json') return _highlightJson(source);
  if (language == 'xml') return _highlightXml(source);

  return [TextSpan(text: source)];
}

/// Tokenises and colourises a JSON string.
List<TextSpan> _highlightJson(String source) {
  final spans = <TextSpan>[];
  var i = 0;

  while (i < source.length) {
    final ch = source[i];

    // Whitespace.
    if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
      spans.add(TextSpan(text: ch));
      i++;
      continue;
    }

    // String.
    if (ch == '"') {
      final start = i;
      i++;
      while (i < source.length) {
        if (source[i] == '\\') {
          i += 2; // skip escaped char
          continue;
        }
        if (source[i] == '"') {
          i++;
          break;
        }
        i++;
      }
      final str = source.substring(start, i);

      // Heuristic: if the previous non-whitespace char was '{' or ',' or
      // the next non-whitespace char is ':', this is likely a key.
      final before = source.substring(0, start).trimRight();
      final isKey = before.isEmpty ||
          before.endsWith('{') ||
          before.endsWith(',') ||
          before.endsWith('[') ||
          before.endsWith(':');

      spans.add(TextSpan(
        text: str,
        style: TextStyle(color: isKey ? SyntaxColors.key : SyntaxColors.string),
      ));
      continue;
    }

    // Number.
    if (_isNumberStart(ch)) {
      final start = i;
      if (ch == '-') i++;
      while (i < source.length && (_isDigit(source[i]) || source[i] == '.')) {
        i++;
      }
      // Handle exponent.
      if (i < source.length && (source[i] == 'e' || source[i] == 'E')) {
        i++;
        if (i < source.length && (source[i] == '+' || source[i] == '-')) i++;
        while (i < source.length && _isDigit(source[i])) i++;
      }
      spans.add(TextSpan(
        text: source.substring(start, i),
        style: const TextStyle(color: SyntaxColors.number),
      ));
      continue;
    }

    // Boolean / null.
    if (source.startsWith('true', i)) {
      spans.add(const TextSpan(
        text: 'true',
        style: TextStyle(color: SyntaxColors.boolean),
      ));
      i += 4;
      continue;
    }
    if (source.startsWith('false', i)) {
      spans.add(const TextSpan(
        text: 'false',
        style: TextStyle(color: SyntaxColors.boolean),
      ));
      i += 5;
      continue;
    }
    if (source.startsWith('null', i)) {
      spans.add(const TextSpan(
        text: 'null',
        style: TextStyle(color: SyntaxColors.boolean),
      ));
      i += 4;
      continue;
    }

    // Punctuation.
    spans.add(TextSpan(
      text: ch,
      style: const TextStyle(color: SyntaxColors.punctuation),
    ));
    i++;
  }

  return spans;
}

/// Tokenises and colourises an XML string.
List<TextSpan> _highlightXml(String source) {
  final spans = <TextSpan>[];
  var i = 0;
  final defaultStyle = TextStyle(color: SyntaxColors.punctuation);

  while (i < source.length) {
    // Tag open.
    if (source[i] == '<') {
      final tagStart = i;
      i++; // skip '<'

      // Closing tag.
      final isClosing = source[i] == '/';
      if (isClosing) i++;

      // Tag name.
      final nameStart = i;
      while (i < source.length && _isXmlNameChar(source[i])) i++;
      final tagName = source.substring(nameStart, i);

      spans.add(TextSpan(
        text: source.substring(tagStart, nameStart),
        style: defaultStyle,
      ));
      spans.add(TextSpan(
        text: tagName,
        style: const TextStyle(color: SyntaxColors.tagName, fontWeight: FontWeight.w600),
      ));

      // Attributes inside tag.
      while (i < source.length && source[i] != '>' && source[i] != '/') {
        if (source[i] == ' ' || source[i] == '\n' || source[i] == '\t') {
          spans.add(TextSpan(text: source[i]));
          i++;
          continue;
        }
        // Attribute name.
        final attrStart = i;
        while (i < source.length &&
            source[i] != '=' &&
            source[i] != '>' &&
            source[i] != '/' &&
            source[i] != ' ') {
          i++;
        }
        spans.add(TextSpan(
          text: source.substring(attrStart, i),
          style: const TextStyle(color: SyntaxColors.key),
        ));
        // Skip '=' and whitespace.
        while (i < source.length &&
            (source[i] == '=' || source[i] == ' ' || source[i] == '\t')) {
          spans.add(TextSpan(text: source[i], style: defaultStyle));
          i++;
        }
        // Attribute value.
        if (i < source.length && source[i] == '"') {
          final valStart = i;
          i++;
          while (i < source.length && source[i] != '"') i++;
          if (i < source.length) i++; // closing quote
          spans.add(TextSpan(
            text: source.substring(valStart, i),
            style: const TextStyle(color: SyntaxColors.attribute),
          ));
        }
      }

      // Closing bracket.
      if (i < source.length) {
        if (source[i] == '/') {
          spans.add(TextSpan(text: '/', style: defaultStyle));
          i++;
        }
        if (i < source.length && source[i] == '>') {
          spans.add(TextSpan(text: '>', style: defaultStyle));
          i++;
        }
      }
      continue;
    }

    // Regular text content.
    final textStart = i;
    while (i < source.length && source[i] != '<') i++;
    if (i > textStart) {
      spans.add(TextSpan(
        text: source.substring(textStart, i),
        style: const TextStyle(color: SyntaxColors.punctuation),
      ));
    }
  }

  return spans;
}

bool _isNumberStart(String ch) => ch == '-' || _isDigit(ch);
bool _isDigit(String ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57;
bool _isXmlNameChar(String ch) =>
    _isAlphaNum(ch) || ch == '-' || ch == '_' || ch == ':';
bool _isAlphaNum(String ch) =>
    _isDigit(ch) ||
    (ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90) ||
    (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122);

/// Validates JSON content and returns a [ValidationResult].
ValidationResult validateJson(String source) {
  if (source.trim().isEmpty) {
    return const ValidationResult(isValid: true);
  }
  try {
    jsonDecode(source);
    return const ValidationResult(isValid: true);
  } on FormatException catch (e) {
    // Parse the error message for line/column info.
    final msg = e.message;
    int? line;
    int? col;

    // dart:convert gives messages like "FormatException: ..." at line X,
    // column Y. Try to extract those numbers.
    final lineMatch = RegExp(r'line (\d+)').firstMatch(msg);
    final colMatch = RegExp(r'column (\d+)').firstMatch(msg);
    if (lineMatch != null) line = int.tryParse(lineMatch.group(1)!);
    if (colMatch != null) col = int.tryParse(colMatch.group(1)!);

    return ValidationResult(
      isValid: false,
      errorMessage: _cleanJsonError(msg),
      errorLine: line,
      errorColumn: col,
    );
  }
}

/// Validates XML content for basic well-formedness.
ValidationResult validateXml(String source) {
  if (source.trim().isEmpty) {
    return const ValidationResult(isValid: true);
  }
  try {
    // Use the xml package for validation.
    // We import it lazily to avoid hard coupling.
    // A simple bracket-matching check:
    final stack = <String>[];
    final tagRegex = RegExp(r'<(/?)([\w:.-]+)[^>]*(/?)>');
    for (final match in tagRegex.allMatches(source)) {
      final isClosing = match.group(1) == '/';
      final isSelfClosing = match.group(3) == '/';
      final name = match.group(2)!;

      if (isSelfClosing) continue;
      if (isClosing) {
        if (stack.isEmpty || stack.last != name) {
          return ValidationResult(
            isValid: false,
            errorMessage: 'Unexpected closing tag </$name>',
          );
        }
        stack.removeLast();
      } else {
        stack.add(name);
      }
    }
    if (stack.isNotEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Unclosed tag <${stack.last}>',
      );
    }
    return const ValidationResult(isValid: true);
  } catch (e) {
    return ValidationResult(isValid: false, errorMessage: e.toString());
  }
}

/// Cleans up the verbose dart:convert JSON error message.
String _cleanJsonError(String msg) {
  // Strip the "FormatException: " prefix if present.
  final clean = msg.replaceFirst(RegExp(r'^FormatException:\s*'), '');
  // Capitalise first letter.
  if (clean.isEmpty) return 'Invalid JSON';
  return clean[0].toUpperCase() + clean.substring(1);
}

// ---------------------------------------------------------------------------
// Syntax Highlight Editor Widget
// ---------------------------------------------------------------------------

/// A multi-line code editor with real-time syntax highlighting and
/// validation for JSON and XML content.
///
/// The editor uses a stacked layout: an invisible [TextField] for input on
/// top, and a read-only [RichText] below showing the highlighted version.
/// Line numbers are rendered on the left gutter.
///
/// A validation indicator (green check / red cross) is displayed in the
/// top-right corner with an optional error tooltip.
class SyntaxHighlightEditor extends StatefulWidget {
  /// The current text content of the editor.
  final String text;

  /// Called when the user modifies the text.
  final ValueChanged<String> onChanged;

  /// The language to highlight: `"json"`, `"xml"`, or any other string
  /// (falls back to plain text).
  final String language;

  /// When `true`, line numbers are displayed on the left gutter.
  final bool showLineNumbers;

  /// Optional hint text shown when the editor is empty.
  final String? hintText;

  /// Minimum height for the editor.
  final double minHeight;

  /// Creates a [SyntaxHighlightEditor].
  const SyntaxHighlightEditor({
    super.key,
    required this.text,
    required this.onChanged,
    this.language = 'json',
    this.showLineNumbers = true,
    this.hintText,
    this.minHeight = 200,
  });

  @override
  State<SyntaxHighlightEditor> createState() => _SyntaxHighlightEditorState();
}

class _SyntaxHighlightEditorState extends State<SyntaxHighlightEditor> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;
  ValidationResult? _validation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    _validate();
  }

  @override
  void didUpdateWidget(covariant SyntaxHighlightEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && _controller.text != widget.text) {
      _controller.text = widget.text;
    }
    _validate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Validates the current content based on the language.
  void _validate() {
    if (widget.language == 'json') {
      _validation = validateJson(widget.text);
    } else if (widget.language == 'xml') {
      _validation = validateXml(widget.text);
    } else {
      _validation = const ValidationResult(isValid: true);
    }
  }

  /// Number of lines in the current text.
  int get _lineCount {
    if (widget.text.isEmpty) return 1;
    return '\n'.allMatches(widget.text).length + 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF5F7FA);
    final gutterColor =
        isDark ? const Color(0xFF16161E) : const Color(0xFFECEFF4);
    final textColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF212121);
    final lineNumColor =
        textColor.withOpacity(0.35);
    final gutterWidth = (_lineCount.toString().length * 9.0 + 24).clamp(36.0, 80.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Validation indicator.
        if (_validation != null && widget.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, right: 4),
            child: _ValidationIndicator(result: _validation!),
          ),

        // Editor container.
        Container(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _focusNode.hasFocus
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Line numbers gutter.
              if (widget.showLineNumbers)
                Container(
                  width: gutterWidth,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: gutterColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: List.generate(_lineCount, (i) {
                        return Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: lineNumColor,
                            height: 1.5,
                          ),
                        );
                      }),
                    ),
                  ),
                ),

              // Code area with stacked text field + highlight overlay.
              Expanded(
                child: Stack(
                  children: [
                    // Highlighted background text (read-only, for display).
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                  height: 1.5,
                                  color: textColor,
                                ),
                                children: widget.text.trim().isEmpty
                                    ? [
                                        TextSpan(
                                          text: widget.hintText ?? '',
                                          style: TextStyle(
                                            color: textColor.withOpacity(0.3),
                                          ),
                                        ),
                                      ]
                                    : highlightSyntax(widget.text, widget.language),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Invisible text field for actual editing.
                    Positioned.fill(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        minLines: null,
                        onChanged: (value) {
                          widget.onChanged(value);
                          _validate();
                        },
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          height: 1.5,
                          color: Colors.transparent,
                        ),
                        cursorColor: theme.colorScheme.primary,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Validation Indicator Widget
// ---------------------------------------------------------------------------

/// A small icon + optional error message that shows the current validation
/// state of the editor content.
class _ValidationIndicator extends StatelessWidget {
  final ValidationResult result;

  const _ValidationIndicator({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result.isValid) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.check_circle,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Valid',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Build the error tooltip message.
    String tooltip = result.errorMessage ?? 'Invalid';
    if (result.errorLine != null) {
      tooltip = 'Line ${result.errorLine}';
      if (result.errorColumn != null) {
        tooltip += ', Column ${result.errorColumn}';
      }
      tooltip += ': $tooltip';
    }

    return Tooltip(
      message: result.errorMessage ?? 'Invalid content',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.error,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              result.errorMessage ?? 'Invalid',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (result.errorLine != null) ...[
            const SizedBox(width: 4),
            Text(
              '(line ${result.errorLine})',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}