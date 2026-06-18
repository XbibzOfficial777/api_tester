/// @file request_settings_panel.dart
/// @brief Per-request settings panel for timeout, redirects, SSL, and proxy.
///
/// Renders a set of toggle switches and input fields that allow the user
/// to fine-tune how the request is executed. Changes are immediately
/// persisted to the [currentRequestProvider].

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/proxy_settings.dart' as proxy_entity;
import 'package:api_tester/presentation/providers/request_provider.dart';

/// A panel of request execution settings.
///
/// Includes:
/// - **Timeout** slider (5–120 seconds) with a numeric text field.
/// - **Follow redirects** toggle.
/// - **Verify SSL** toggle.
/// - **Proxy** section with host, port, type, and optional auth fields.
class RequestSettingsPanel extends ConsumerStatefulWidget {
  /// Creates a [RequestSettingsPanel].
  const RequestSettingsPanel({super.key});

  @override
  ConsumerState<RequestSettingsPanel> createState() =>
      _RequestSettingsPanelState();
}

class _RequestSettingsPanelState extends ConsumerState<RequestSettingsPanel> {
  /// Controller for the proxy host text field.
  late final TextEditingController _proxyHostController;

  /// Controller for the proxy port text field.
  late final TextEditingController _proxyPortController;

  /// Controller for the proxy username text field.
  final _proxyUsernameController = TextEditingController();

  /// Controller for the proxy password text field.
  final _proxyPasswordController = TextEditingController();

  /// Locally cached proxy type so we can build a full ProxySettings object.
  RequestProxyType _proxyType = RequestProxyType.http;

  @override
  void initState() {
    super.initState();
    _proxyHostController = TextEditingController();
    _proxyPortController = TextEditingController();
  }

  @override
  void dispose() {
    _proxyHostController.dispose();
    _proxyPortController.dispose();
    _proxyUsernameController.dispose();
    _proxyPasswordController.dispose();
    super.dispose();
  }

  /// Builds a [proxy_entity.ProxySettings] from the current local state
  /// and the form state, and pushes it to the notifier.
  void _applyProxySettings() {
    final formState = ref.read(currentRequestProvider);
    final host = _proxyHostController.text.trim();
    final port = int.tryParse(_proxyPortController.text) ?? 8080;

    final proxyType = _proxyType == RequestProxyType.http
        ? proxy_entity.ProxyType.http
        : proxy_entity.ProxyType.socks5;

    final settings = proxy_entity.ProxySettings(
      enabled: formState.useProxy,
      host: host,
      port: port,
      type: proxyType,
      username: _proxyUsernameController.text.trim().isNotEmpty
          ? _proxyUsernameController.text.trim()
          : null,
      password: _proxyPasswordController.text.isNotEmpty
          ? _proxyPasswordController.text
          : null,
    );

    ref.read(currentRequestProvider.notifier).setProxySettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(currentRequestProvider);
    final notifier = ref.read(currentRequestProvider.notifier);

    // Sync proxy controllers on first build.
    if (_proxyHostController.text != formState.proxyHost &&
        _proxyHostController.text.isEmpty) {
      _proxyHostController.text = formState.proxyHost;
    }
    if (_proxyPortController.text != formState.proxyPort.toString() &&
        _proxyPortController.text.isEmpty) {
      _proxyPortController.text = formState.proxyPort.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeout ─────────────────────────────────────────────────────
        _SettingsSectionHeader(
          icon: Symbols.timer,
          title: 'Timeout',
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: formState.timeoutSeconds.toDouble(),
                min: 5,
                max: 120,
                divisions: 23,
                label: '${formState.timeoutSeconds}s',
                onChanged: (v) => notifier.setTimeout(v.round()),
              ),
            ),
            SizedBox(
              width: 64,
              height: 36,
              child: TextField(
                controller: TextEditingController(
                  text: formState.timeoutSeconds.toString(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null && parsed >= 5 && parsed <= 120) {
                    notifier.setTimeout(parsed);
                  }
                },
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  suffixText: 's',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Range: 5 – 120 seconds',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        // ── Follow Redirects ─────────────────────────────────────────────
        SwitchListTile(
          value: formState.followRedirects,
          onChanged: (v) => notifier.setFollowRedirects(v),
          title: const Text('Follow Redirects'),
          subtitle: const Text('Automatically follow HTTP 3xx redirects'),
          secondary: const Icon(Symbols.arrow_forward, size: 22),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        const SizedBox(height: 8),

        // ── Verify SSL ──────────────────────────────────────────────────
        SwitchListTile(
          value: formState.verifySsl,
          onChanged: (v) => notifier.setVerifySsl(v),
          title: const Text('Verify SSL Certificate'),
          subtitle: const Text('Validate the server\'s SSL/TLS certificate'),
          secondary: const Icon(Symbols.verified_user, size: 22),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        const SizedBox(height: 16),
        Divider(color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 12),

        // ── Proxy Settings ──────────────────────────────────────────────
        _SettingsSectionHeader(
          icon: Symbols.vpn_lock,
          title: 'Proxy Settings',
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: formState.useProxy,
          onChanged: (v) {
            if (v) {
              // Enable proxy – push current field values.
              _applyProxySettings();
            } else {
              // Disable proxy.
              ref
                  .read(currentRequestProvider.notifier)
                  .setProxySettings(null);
            }
          },
          title: const Text('Enable Proxy'),
          subtitle: const Text('Route this request through a proxy server'),
          secondary: const Icon(Symbols.lan, size: 22),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // Proxy configuration fields (shown when enabled).
        if (formState.useProxy) ...[
          const SizedBox(height: 12),
          _buildProxyFields(formState, theme),
        ],
      ],
    );
  }

  /// Builds the proxy host, port, type, and optional auth fields.
  Widget _buildProxyFields(dynamic formState, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Proxy type selector.
          Text(
            'Proxy Type',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<RequestProxyType>(
            segments: const [
              ButtonSegment(
                value: RequestProxyType.http,
                label: Text('HTTP', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment(
                value: RequestProxyType.socks5,
                label: Text('SOCKS5', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_proxyType},
            onSelectionChanged: (selected) {
              setState(() => _proxyType = selected.first);
              _applyProxySettings();
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 14),

          // Host and Port row.
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _proxyHostController,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: '192.168.1.1',
                    isDense: true,
                  ),
                  onChanged: (_) => _applyProxySettings(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _proxyPortController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '8080',
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _applyProxySettings(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Optional: Username.
          TextField(
            controller: _proxyUsernameController,
            decoration: const InputDecoration(
              labelText: 'Username (optional)',
              hintText: 'proxy_user',
              isDense: true,
              prefixIcon: Icon(Symbols.person, size: 18),
            ),
          ),
          const SizedBox(height: 10),

          // Optional: Password.
          TextField(
            controller: _proxyPasswordController,
            decoration: const InputDecoration(
              labelText: 'Password (optional)',
              hintText: '••••••••',
              isDense: true,
              prefixIcon: Icon(Symbols.lock, size: 18),
            ),
            obscureText: true,
          ),
        ],
      ),
    );
  }
}

/// A small section header with an icon and title text.
class _SettingsSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SettingsSectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}