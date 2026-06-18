/// @file proxy_settings.dart
/// @brief Domain entity for proxy configuration.
///
/// Encapsulates all settings needed to route HTTP requests through
/// a proxy server. Supports both HTTP and SOCKS5 proxy types with
/// optional authentication.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'proxy_settings.freezed.dart';
part 'proxy_settings.g.dart';

/// The type of proxy protocol to use.
enum ProxyType {
  /// Standard HTTP/HTTPS proxy.
  @JsonValue('http')
  http,

  /// SOCKS5 proxy protocol.
  @JsonValue('socks5')
  socks5,
}

/// Configuration for routing requests through a proxy server.
///
/// Used both at the global app level and per-request level to direct
/// outgoing HTTP traffic through an intermediary server.
@freezed
class ProxySettings with _$ProxySettings {
  /// Creates a new [ProxySettings] instance.
  ///
  /// [enabled] - Whether the proxy is currently active.
  /// [host] - Proxy server hostname or IP address.
  /// [port] - Proxy server port number.
  /// [type] - The proxy protocol type. Defaults to [ProxyType.http].
  /// [username] - Optional username for proxy authentication.
  /// [password] - Optional password for proxy authentication.
  const factory ProxySettings({
    required bool enabled,
    required String host,
    required int port,
    @Default(ProxyType.http) ProxyType type,
    String? username,
    String? password,
  }) = _ProxySettings;

  /// Deserializes a [ProxySettings] from a JSON map.
  factory ProxySettings.fromJson(Map<String, dynamic> json) =>
      _$ProxySettingsFromJson(json);
}