/// @file proxy_settings_screen.dart
/// @brief Screen for configuring global proxy settings.
///
/// Provides a form to enable/disable proxy, select the proxy type (HTTP or
/// SOCKS5), configure host, port, and optional authentication credentials.
/// Includes a "Test Connection" button that sends a simple request through
/// the configured proxy to verify connectivity.

library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/core/extensions/string_extensions.dart';
import 'package:api_tester/domain/entities/proxy_settings.dart';
import 'package:api_tester/presentation/providers/settings_provider.dart';

/// Global proxy configuration screen.
///
/// Reads the current [ProxySettings] from [settingsProvider] and provides
/// a form to modify all proxy-related fields. Changes are persisted
/// immediately when the user taps "Save".
class ProxySettingsScreen extends ConsumerStatefulWidget {
  /// Creates a [ProxySettingsScreen].
  const ProxySettingsScreen({super.key});

  @override
  ConsumerState<ProxySettingsScreen> createState() =>
      _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends ConsumerState<ProxySettingsScreen> {
  // ---------------------------------------------------------------------------
  // Controllers
  // ---------------------------------------------------------------------------

  /// Controller for the host field.
  final _hostController = TextEditingController();

  /// Controller for the port field.
  final _portController = TextEditingController();

  /// Controller for the username field.
  final _usernameController = TextEditingController();

  /// Controller for the password field.
  final _passwordController = TextEditingController();

  /// Form key for validation.
  final _formKey = GlobalKey<FormState>();

  // ---------------------------------------------------------------------------
  // Local state
  // ---------------------------------------------------------------------------

  /// Whether the proxy is enabled.
  bool _enabled = false;

  /// The selected proxy type.
  ProxyType _proxyType = ProxyType.http;

  /// Whether the password field is obscured.
  bool _obscurePassword = true;

  /// Whether a test connection is in progress.
  bool _isTesting = false;

  /// Whether a save operation is in progress.
  bool _isSaving = false;

  /// Result message from the test connection.
  String? _testResult;

  /// Whether the test was successful.
  bool _testSuccess = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Populates form fields from the current app settings.
  void _loadFromSettings() {
    // Use addPostFrameCallback to access the ref after the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final settings = ref.read(settingsProvider);
      final proxy = settings.globalProxy;

      setState(() {
        _enabled = proxy?.enabled ?? false;
        _proxyType = proxy?.type ?? ProxyType.http;
        _hostController.text = proxy?.host ?? '';
        _portController.text = proxy?.port.toString() ?? '8080';
        _usernameController.text = proxy?.username ?? '';
        _passwordController.text = proxy?.password ?? '';
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Validates the form and saves the proxy settings.
  Future<void> _save() async {
    if (!_enabled) {
      // If disabled, just clear the global proxy.
      await ref.read(settingsProvider.notifier).updateGlobalProxy(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proxy disabled'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final port = int.tryParse(_portController.text.trim()) ?? 8080;
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final proxySettings = ProxySettings(
        enabled: true,
        host: _hostController.text.trim(),
        port: port,
        type: _proxyType,
        username: username.isNotEmpty ? username : null,
        password: password.isNotEmpty ? password : null,
      );

      await ref.read(settingsProvider.notifier).updateGlobalProxy(proxySettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proxy settings saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Tests the current proxy configuration by sending a request through it.
  Future<void> _testConnection() async {
    if (_enabled && (_hostController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a proxy host'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 8080;

      // Build proxy configuration for Dio.
      final proxyUrl = '${_proxyType.name}://$host:$port';

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      // Configure the proxy adapter based on type.
      if (_proxyType == ProxyType.http) {
        final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (uri) => proxyUrl;
          return client;
        };
      }

      // Send a test request to a well-known endpoint.
      final response = await dio.get('https://httpbin.org/ip');

      if (mounted) {
        setState(() {
          _testSuccess = true;
          _testResult =
              'Connection successful (${response.statusCode}). '
              'Response: ${response.data.toString().truncate(200)}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testSuccess = false;
          _testResult = 'Connection failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -----------------------------------------------------------------
            // Enable / Disable toggle
            // -----------------------------------------------------------------
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _enabled ? Symbols.vpn_lock : Symbols.vpn_lock_off,
                color: _enabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'Enable Proxy',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _enabled ? 'All requests will be routed through the proxy' : 'Proxy is currently disabled',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              value: _enabled,
              onChanged: (v) => setState(() {
                _enabled = v;
                _testResult = null;
              }),
            ),

            const SizedBox(height: 24),

            // -----------------------------------------------------------------
            // Proxy configuration (only visible when enabled)
            // -----------------------------------------------------------------
            if (_enabled) ...[
              // Proxy type selector.
              Row(
                children: [
                  Icon(
                    Symbols.category,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Proxy Type',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<ProxyType>(
                segments: const [
                  ButtonSegment(
                    value: ProxyType.http,
                    label: Text('HTTP'),
                    icon: Icon(Symbols.http, size: 18),
                  ),
                  ButtonSegment(
                    value: ProxyType.socks5,
                    label: Text('SOCKS5'),
                    icon: Icon(Symbols.lock, size: 18),
                  ),
                ],
                selected: {_proxyType},
                onSelectionChanged: (selection) {
                  setState(() => _proxyType = selection.first);
                },
              ),
              const SizedBox(height: 20),

              // Host field.
              TextFormField(
                controller: _hostController,
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (_enabled && (value?.trim().isEmpty ?? true)) {
                    return 'Host is required when proxy is enabled';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: 'e.g. proxy.example.com or 192.168.1.100',
                  prefixIcon: Icon(Symbols.dns, size: 20),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Port field.
              TextFormField(
                controller: _portController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (_enabled) {
                    final port = int.tryParse(value?.trim() ?? '');
                    if (port == null || port < 1 || port > 65535) {
                      return 'Enter a valid port (1-65535)';
                    }
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: 'e.g. 8080',
                  prefixIcon: Icon(Symbols.numbers, size: 20),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              // -----------------------------------------------------------------
              // Authentication section (optional)
              // -----------------------------------------------------------------
              Row(
                children: [
                  Icon(
                    Symbols.key,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Authentication (optional)',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Username.
              TextFormField(
                controller: _usernameController,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Leave empty if no auth required',
                  prefixIcon: Icon(Symbols.person, size: 20),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // Password.
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Leave empty if no auth required',
                  prefixIcon: const Icon(Symbols.lock, size: 20),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Symbols.visibility
                          : Symbols.visibility_off,
                      size: 20,
                    ),
                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // -----------------------------------------------------------------
              // Test connection
              // -----------------------------------------------------------------
              OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.wifi_tethering, size: 18),
                label: Text(_isTesting ? 'Testing…' : 'Test Connection'),
              ),

              // Test result message.
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess
                        ? colorScheme.primaryContainer
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _testSuccess
                            ? Symbols.check_circle
                            : Symbols.error,
                        size: 18,
                        color: _testSuccess
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: textTheme.bodySmall?.copyWith(
                            color: _testSuccess
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            // -----------------------------------------------------------------
            // When proxy is disabled, show info message.
            // -----------------------------------------------------------------
            if (!_enabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Icon(
                      Symbols.vpn_lock_off,
                      size: 48,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Proxy is disabled',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enable the toggle above to configure a proxy server '
                      'for routing all API requests.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom padding for save bar.
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(colorScheme),
    );
  }

  /// Builds the bottom bar with Cancel and Save buttons.
  Widget _buildBottomBar(ColorScheme colorScheme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            // Cancel button.
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),

            // Save button.
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Symbols.check, size: 18),
                label: Text(_isSaving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}