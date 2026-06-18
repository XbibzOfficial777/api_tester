/// @file app_settings.dart
/// @brief Domain entity for application-wide settings.
///
/// Centralizes all user-configurable preferences for the API Tester
/// application, including appearance defaults, network behavior defaults,
/// proxy configuration, and feature toggles.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import 'proxy_settings.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// The application theme preference.
enum ThemeMode {
  /// Follows the system's current theme (light or dark).
  @JsonValue('system')
  system,

  /// Forces light theme regardless of system setting.
  @JsonValue('light')
  light,

  /// Forces dark theme regardless of system setting.
  @JsonValue('dark')
  dark,
}

/// Application-wide settings and user preferences.
///
/// Persists across app sessions and affects default behavior for
/// new requests, UI appearance, and optional features.
@freezed
class AppSettings with _$AppSettings {
  /// Creates a new [AppSettings] instance with sensible defaults.
  ///
  /// [themeMode] - UI theme preference. Defaults to system theme.
  /// [defaultTimeout] - Default request timeout in seconds. Defaults to 30.
  /// [defaultFollowRedirects] - Whether to follow HTTP 3xx redirects by default.
  /// [defaultVerifySsl] - Whether to verify SSL certificates by default.
  /// [globalProxy] - Optional proxy settings applied to all requests.
  /// [fontSize] - Base font size for the code/body editor. Defaults to 14.0.
  /// [sendAnalytics] - Whether anonymous usage analytics are enabled.
  /// [floatingWindowEnabled] - Whether the floating window feature is enabled.
  const factory AppSettings({
    @Default(ThemeMode.system) ThemeMode themeMode,
    @Default(30) int defaultTimeout,
    @Default(true) bool defaultFollowRedirects,
    @Default(true) bool defaultVerifySsl,
    ProxySettings? globalProxy,
    @Default(14.0) double fontSize,
    @Default(false) bool sendAnalytics,
    @Default(false) bool floatingWindowEnabled,
  }) = _AppSettings;

  /// Deserializes an [AppSettings] from a JSON map.
  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}