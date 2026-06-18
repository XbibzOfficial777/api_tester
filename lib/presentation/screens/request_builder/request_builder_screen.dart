/// @file request_builder_screen.dart
/// @brief The main Request Builder screen – the heart of the API Tester app.
///
/// This screen composes all request-building sub-widgets into a single
/// scrollable view:
///
/// 1. **URL Input Bar** – method selector + URL field + send button
/// 2. **Expandable Sections** (animated expand/collapse via [AnimatedSize]):
///    - Headers
///    - Query Params
///    - Body (with body-type sub-selector)
///    - Auth (quick Bearer token input)
///    - Settings (timeout, SSL, proxy)
/// 3. **Response Viewer** – shown below the request form when a response
///    is available.
/// 4. **Floating Action Button** – saves the current request.
///
/// The screen uses Riverpod for state management and Material Design 3
/// components throughout. It is responsive, adapting its layout for both
/// phone and tablet form factors.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/api_response.dart';
import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/presentation/providers/request_provider.dart';
import 'widgets/headers_editor.dart';
import 'widgets/params_editor.dart';
import 'widgets/body_editor.dart';
import 'widgets/request_settings_panel.dart';
import 'widgets/response_viewer.dart';
import 'widgets/url_input_bar.dart';

/// The main Request Builder screen.
///
/// This is the primary screen of the API Tester app. It allows users to
/// compose and send HTTP requests, view responses, and save requests to
/// their workspace.
///
/// The screen is split into two main areas:
/// - **Top half**: Request configuration (URL, method, headers, params,
///   body, auth, settings).
/// - **Bottom half**: Response viewer (visible after a request is sent).
///
/// On wide screens (tablets / landscape), the request and response areas
/// are displayed side by side.
class RequestBuilderScreen extends ConsumerStatefulWidget {
  /// Route name for navigation.
  static const String routeName = '/request-builder';

  /// Optional ID of an existing request to load for editing.
  final String? requestId;

  /// Creates a [RequestBuilderScreen].
  const RequestBuilderScreen({super.key, this.requestId});

  @override
  ConsumerState<RequestBuilderScreen> createState() =>
      _RequestBuilderScreenState();
}

class _RequestBuilderScreenState extends ConsumerState<RequestBuilderScreen> {
  // --- Expanded section state -----------------------------------------------
  /// Which sections are currently expanded. Keys match [SectionKey] values.
  final Set<String> _expandedSections = {};

  // --- Auth field controllers ------------------------------------------------
  late final TextEditingController _authTokenController;
  bool _useAuth = false;

  @override
  void initState() {
    super.initState();
    _authTokenController = TextEditingController();

    // Expand Headers and Body by default.
    _expandedSections.add(SectionKey.headers);
    _expandedSections.add(SectionKey.body);
  }

  @override
  void dispose() {
    _authTokenController.dispose();
    super.dispose();
  }

  /// Sends the request by invoking the provider callback.
  void _sendRequest() {
    // Apply auth token if enabled.
    if (_useAuth && _authTokenController.text.isNotEmpty) {
      final notifier = ref.read(currentRequestProvider.notifier);
      final formState = ref.read(currentRequestProvider);
      final token = _authTokenController.text.trim();

      // Find or add an Authorization header.
      final existingAuth = formState.headers.indexWhere(
        (h) => h.key.toLowerCase() == 'authorization',
      );

      if (existingAuth >= 0) {
        notifier.updateHeader(
          existingAuth,
          key: 'Authorization',
          value: 'Bearer $token',
        );
      } else {
        notifier.addHeader(key: 'Authorization', value: 'Bearer $token');
      }
    }

    // Trigger send via the provider.
    ref.read(sendRequestProvider)();
  }

  /// Saves the current request (shows a snackbar confirmation).
  void _saveRequest() {
    final formState = ref.read(currentRequestProvider);
    // In production this would call the save request use case.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Request saved'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(currentRequestProvider);
    final response = ref.watch(responseProvider);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Builder'),
        actions: [
          // Save button in app bar.
          IconButton(
            icon: const Icon(Symbols.save),
            tooltip: 'Save Request',
            onPressed: _saveRequest,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isWide
          ? _buildWideLayout(formState, response, theme)
          : _buildNarrowLayout(formState, response, theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveRequest,
        icon: const Icon(Symbols.save),
        label: const Text('Save'),
      ),
    );
  }

  /// Wide (tablet/landscape) layout with request and response side by side.
  Widget _buildWideLayout(dynamic formState, ApiResponse? response, ThemeData theme) {
    return Row(
      children: [
        // Left: Request builder.
        Expanded(
          flex: 5,
          child: _buildRequestColumn(formState),
        ),
        const VerticalDivider(width: 1),

        // Right: Response viewer.
        Expanded(
          flex: 5,
          child: response != null
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: const ResponseViewer(),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Symbols.send,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Send a request to see the response',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  /// Narrow (phone) layout with request on top and response below.
  Widget _buildNarrowLayout(dynamic formState, ApiResponse? response, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL input bar.
          UrlInputBar(onSend: _sendRequest),
          const SizedBox(height: 12),

          // Request sections.
          _buildRequestSections(formState),

          // Response viewer (only on narrow when response exists).
          if (response != null) ...[
            const SizedBox(height: 16),
            const ResponseViewer(),
          ],
        ],
      ),
    );
  }

  /// The request-building column containing all expandable sections.
  /// Used in wide layout with its own scroll view.
  Widget _buildRequestColumn(dynamic formState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL input bar.
          UrlInputBar(onSend: _sendRequest),
          const SizedBox(height: 12),

          // Request sections.
          _buildRequestSections(formState),
        ],
      ),
    );
  }

  /// Builds all the expandable request sections.
  Widget _buildRequestSections(dynamic formState) {
    final headers = formState.headers as List<KeyValueItem>;
    final queryParams = formState.queryParams as List<KeyValueItem>;
    final bodyType = formState.bodyType as BodyType;
    final timeout = formState.timeoutSeconds as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Headers Section ──────────────────────────────────────────────
        _ExpandableSection(
          sectionKey: SectionKey.headers,
          isExpanded: _expandedSections.contains(SectionKey.headers),
          icon: Symbols.data_object,
          title: 'Headers',
          subtitle: HeadersEditor.subtitle(headers),
          onToggle: () => _toggleSection(SectionKey.headers),
          child: const HeadersEditor(),
        ),
        const SizedBox(height: 4),

        // ── Query Params Section ─────────────────────────────────────────
        _ExpandableSection(
          sectionKey: SectionKey.params,
          isExpanded: _expandedSections.contains(SectionKey.params),
          icon: Symbols.query_stats,
          title: 'Query Params',
          subtitle: ParamsEditor.subtitle(queryParams),
          onToggle: () => _toggleSection(SectionKey.params),
          child: const ParamsEditor(),
        ),
        const SizedBox(height: 4),

        // ── Body Section ─────────────────────────────────────────────────
        _ExpandableSection(
          sectionKey: SectionKey.body,
          isExpanded: _expandedSections.contains(SectionKey.body),
          icon: Symbols.code,
          title: 'Body',
          subtitle: bodyType == BodyType.none
              ? 'None'
              : bodyType.label,
          onToggle: () => _toggleSection(SectionKey.body),
          child: const BodyEditor(),
        ),
        const SizedBox(height: 4),

        // ── Auth Section ──────────────────────────────────────────────────
        _ExpandableSection(
          sectionKey: SectionKey.auth,
          isExpanded: _expandedSections.contains(SectionKey.auth),
          icon: Symbols.key,
          title: 'Auth',
          subtitle: _useAuth ? 'Bearer Token' : 'No auth',
          onToggle: () => _toggleSection(SectionKey.auth),
          child: _buildAuthSection(),
        ),
        const SizedBox(height: 4),

        // ── Settings Section ──────────────────────────────────────────────
        _ExpandableSection(
          sectionKey: SectionKey.settings,
          isExpanded: _expandedSections.contains(SectionKey.settings),
          icon: Symbols.settings,
          title: 'Settings',
          subtitle: 'Timeout: ${timeout}s',
          onToggle: () => _toggleSection(SectionKey.settings),
          child: const RequestSettingsPanel(),
        ),
      ],
    );
  }

  /// Builds the quick auth section with a Bearer token toggle and input.
  Widget _buildAuthSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enable auth toggle.
        SwitchListTile(
          value: _useAuth,
          onChanged: (v) => setState(() => _useAuth = v),
          title: const Text('Bearer Token'),
          subtitle: const Text('Add an Authorization: Bearer header'),
          secondary: const Icon(Symbols.lock, size: 22),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // Token input (shown when auth is enabled).
        if (_useAuth) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _authTokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Token',
              hintText: 'Enter your Bearer token',
              prefixIcon: const Icon(Symbols.vpn_key, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Symbols.visibility, size: 18),
                onPressed: () {
                  // Reveal the token in a snackbar momentarily.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Token: ${_authTokenController.text}',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The token will be sent as: Authorization: Bearer <token>',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// Toggles a section's expanded/collapsed state.
  void _toggleSection(String key) {
    setState(() {
      if (_expandedSections.contains(key)) {
        _expandedSections.remove(key);
      } else {
        _expandedSections.add(key);
      }
    });
  }
}

// =============================================================================
// Section Keys
// =============================================================================

/// String constants used as keys for expandable sections.
abstract class SectionKey {
  /// Headers section.
  static const String headers = 'headers';

  /// Query params section.
  static const String params = 'params';

  /// Body section.
  static const String body = 'body';

  /// Auth section.
  static const String auth = 'auth';

  /// Settings section.
  static const String settings = 'settings';
}

// =============================================================================
// Expandable Section Widget
// =============================================================================

/// An animated expand/collapse section with a header row and content.
///
/// The header shows an icon, title, subtitle, and a chevron that rotates
/// when the section is toggled. The content fades and slides in/out
/// smoothly using [AnimatedSize] and [AnimatedOpacity].
class _ExpandableSection extends StatelessWidget {
  /// Unique key for this section (used for identity and state tracking).
  final String sectionKey;

  /// Whether the section is currently expanded.
  final bool isExpanded;

  /// Material Symbols icon for the section header.
  final IconData icon;

  /// Section title.
  final String title;

  /// Optional subtitle (e.g. item count or body type).
  final String subtitle;

  /// Called when the header is tapped to toggle expansion.
  final VoidCallback onToggle;

  /// The content shown when expanded.
  final Widget child;

  const _ExpandableSection({
    required this.sectionKey,
    required this.isExpanded,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable header row.
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Animated chevron.
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Symbols.expand_more,
                      size: 22,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated content area.
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? AnimatedOpacity(
                    opacity: isExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: child,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}