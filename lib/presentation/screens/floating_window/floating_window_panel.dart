/// @file floating_window_panel.dart
/// @brief Flutter widget that defines the layout structure for the floating
/// window panel.
///
/// This widget represents the *design reference* for the floating window UI.
/// The actual system overlay rendered by [SystemAlertWindow] uses a native
/// declarative API (rows/columns), not a Flutter widget tree. However, this
/// widget serves three important purposes:
///
/// 1. **Design reference** — it shows exactly what the native overlay should
///    look like, so any visual changes can be prototyped in Flutter first.
/// 2. **Preview / testing** — it can be embedded in a regular Flutter screen
///    to test the layout without needing the system overlay permission.
/// 3. **Documentation** — the code clearly documents the intended structure.
///
/// The layout includes:
/// - Method dropdown (GET, POST, PUT, DELETE)
/// - Compact URL text field
/// - Send button
/// - Response status and body preview (truncated to ~4 lines)
/// - "Open App" button
/// - Close button
///
/// All elements are designed to be compact and responsive, suitable for an
/// overlay that floats above other applications.

library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/api_request.dart';

/// A compact, self-contained widget that mirrors the floating window panel.
///
/// This widget is **not** used directly as the system overlay (the overlay
/// uses [SystemAlertWindow]'s native API). Instead it serves as the
/// Flutter-side design reference and can be used for in-app previews.
///
/// Use the [FloatingWindowPanel.preview] constructor to create a
/// non-interactive preview, or the default constructor for a fully
/// functional panel with callbacks.
///
/// Example (in-app preview):
/// ```dart
/// FloatingWindowPanel(
///   onSend: (method, url) => print('$method $url'),
///   onOpenApp: () => Navigator.pop(context),
///   onClose: () => Navigator.pop(context),
/// )
/// ```
class FloatingWindowPanel extends StatefulWidget {
  /// Creates an interactive [FloatingWindowPanel] with the given callbacks.
  const FloatingWindowPanel({
    super.key,
    this.onSend,
    this.onOpenApp,
    this.onClose,
    this.initialMethod = 'GET',
    this.initialUrl = '',
    this.responseStatus,
    this.responseBody,
  });

  /// Creates a non-interactive preview of the panel.
  ///
  /// Useful for documentation screenshots or design reviews.
  const FloatingWindowPanel.preview({
    super.key,
    this.responseStatus,
    this.responseBody,
  })  : onSend = null,
        onOpenApp = null,
        onClose = null,
        initialMethod = 'GET',
        initialUrl = '';

  /// Callback invoked when the user taps the Send button.
  ///
  /// Receives the selected HTTP method and entered URL.
  final void Function(String method, String url)? onSend;

  /// Callback invoked when the user taps the "Open App" button.
  final VoidCallback? onOpenApp;

  /// Callback invoked when the user taps the Close button.
  final VoidCallback? onClose;

  /// The initial HTTP method selected in the dropdown.
  final String initialMethod;

  /// The initial URL shown in the text field.
  final String initialUrl;

  /// Optional pre-filled response status (e.g. `"200 OK"`).
  final String? responseStatus;

  /// Optional pre-filled response body preview.
  final String? responseBody;

  @override
  State<FloatingWindowPanel> createState() => _FloatingWindowPanelState();
}

class _FloatingWindowPanelState extends State<FloatingWindowPanel> {
  late String _selectedMethod;
  late TextEditingController _urlController;
  String? _status;
  String? _body;
  bool _isSending = false;

  /// The maximum number of lines shown in the response body preview.
  static const int _maxBodyLines = 4;

  /// The maximum character length for the response body preview.
  static const int _maxBodyChars = 300;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.initialMethod;
    _urlController = TextEditingController(text: widget.initialUrl);
    _status = widget.responseStatus;
    _body = widget.responseBody;
  }

  @override
  void didUpdateWidget(covariant FloatingWindowPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.responseStatus != oldWidget.responseStatus) {
      _status = widget.responseStatus;
    }
    if (widget.responseBody != oldWidget.responseBody) {
      _body = widget.responseBody;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Handles the Send button press.
  Future<void> _handleSend() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    if (widget.onSend == null) return;

    setState(() {
      _isSending = true;
      _status = 'Sending...';
      _body = null;
    });

    widget.onSend!(_selectedMethod, url);

    // If the caller does not update status/body, reset after a delay.
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isSending) {
      setState(() => _isSending = false);
    }
  }

  /// Truncates a body string for display in the compact preview.
  String _truncateBody(String text) {
    if (text.length <= _maxBodyChars) return text;
    return '${text.substring(0, _maxBodyChars)}...';
  }

  /// Returns the colour for a given status string.
  Color _statusColor(String status) {
    if (status.startsWith('2')) return AppTheme.status2xx;
    if (status.startsWith('3')) return AppTheme.status3xx;
    if (status.startsWith('4')) return AppTheme.status4xx;
    if (status.startsWith('5')) return AppTheme.status5xx;
    return Colors.grey;
  }

  /// Parses a method string into an [HttpMethod] enum value.
  HttpMethod _parseMethod(String method) {
    return HttpMethod.values.firstWhere(
      (m) => m.name.toUpperCase() == method.toUpperCase(),
      orElse: () => HttpMethod.get,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 380,
      constraints: const BoxConstraints(maxHeight: 520),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Header --
          _buildHeader(colorScheme),

          // -- Body --
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Method selector
                _buildMethodSelector(theme, colorScheme),

                const SizedBox(height: 6),

                // URL input
                _buildUrlInput(theme, colorScheme),

                const SizedBox(height: 8),

                // Action buttons
                _buildActionButtons(colorScheme),

                const SizedBox(height: 8),

                // Response status
                _buildResponseStatus(colorScheme),

                const SizedBox(height: 4),

                // Response body preview
                _buildResponseBodyPreview(theme, colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the panel header with the app title.
  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primarySeed,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.http_rounded,
            color: colorScheme.onPrimary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'API Tester',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the HTTP method selector row.
  Widget _buildMethodSelector(ThemeData theme, ColorScheme colorScheme) {
    const methods = ['GET', 'POST', 'PUT', 'DELETE'];

    return Row(
      children: methods.map((method) {
        final isSelected = method == _selectedMethod;
        final httpMethod = _parseMethod(method);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: isSelected
                  ? AppTheme.statusCodeColor(
                      _statusCodeForMethod(httpMethod))
                  : colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: widget.onSend != null
                    ? () => setState(() => _selectedMethod = method)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  child: Text(
                    method,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.statusCodeColor(
                              _statusCodeForMethod(httpMethod)),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Maps an [HttpMethod] to a representative status code for colouring.
  static int _statusCodeForMethod(HttpMethod method) {
    return switch (method) {
      HttpMethod.get => 200,
      HttpMethod.post => 201,
      HttpMethod.put => 200,
      HttpMethod.delete => 204,
      HttpMethod.patch => 206,
      HttpMethod.head => 200,
      HttpMethod.options => 204,
    };
  }

  /// Builds the compact URL input field.
  Widget _buildUrlInput(ThemeData theme, ColorScheme colorScheme) {
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _urlController,
        enabled: widget.onSend != null,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: 'https://api.example.com/endpoint',
          hintStyle: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: colorScheme.outlineVariant,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 1.5,
            ),
          ),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        ),
      ),
    );
  }

  /// Builds the row of action buttons (Send, Open App, Close).
  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Row(
      children: [
        // Send button (takes 2x space)
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 34,
            child: FilledButton.icon(
              onPressed: _isSending ? null : _handleSend,
              icon: _isSending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                _isSending ? 'Sending' : 'Send',
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Open App button
        Expanded(
          child: SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenApp,
              icon: const Icon(Icons.open_in_app_rounded, size: 14),
              label: const Text('App', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: colorScheme.primary,
                side: BorderSide(color: colorScheme.primary.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Close button
        Expanded(
          child: SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, size: 14),
              label: const Text('Close', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: colorScheme.error,
                side: BorderSide(color: colorScheme.error.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the response status indicator.
  Widget _buildResponseStatus(ColorScheme colorScheme) {
    final statusText = _status ?? 'Status: ---';
    final isDefault = _status == null;
    final statusClr = isDefault
        ? colorScheme.onSurfaceVariant
        : _statusColor(statusText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isDefault
            ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : _statusColor(statusText).withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (!isDefault)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: statusClr,
                shape: BoxShape.circle,
              ),
            ),
          Flexible(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isDefault ? FontWeight.normal : FontWeight.bold,
                color: statusClr,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the response body preview area.
  Widget _buildResponseBodyPreview(ThemeData theme, ColorScheme colorScheme) {
    final bodyText = _body;
    final displayText = bodyText != null && bodyText.isNotEmpty
        ? _truncateBody(bodyText)
        : 'Response will appear here...';
    final isEmpty = bodyText == null || bodyText.isEmpty;

    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEmpty
            ? colorScheme.surfaceContainerHighest.withOpacity(0.2)
            : AppTheme.codeBackgroundLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        displayText,
        maxLines: _maxBodyLines,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isEmpty
              ? colorScheme.onSurfaceVariant.withOpacity(0.5)
              : colorScheme.onSurface,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }
}