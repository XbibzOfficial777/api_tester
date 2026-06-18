/// @file floating_window_provider.dart
/// @brief Riverpod providers for the floating window feature.
///
/// Manages the floating window lifecycle: permission requests, enabling /
/// disabling the overlay, and sending quick requests from the floating
/// window. The feature toggle is derived from [settingsProvider].

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/api_response.dart';
import 'package:api_tester/domain/entities/key_value_item.dart';
import 'package:api_tester/domain/repositories/request_repository.dart';
import 'package:api_tester/presentation/providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Whether the floating window feature is enabled in app settings.
///
/// Derived from [settingsProvider]. The UI should hide the floating
/// window toggle when this is `false`.
final floatingWindowEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.floatingWindowEnabled;
});

/// Tracks whether the floating window is currently active / visible.
///
/// This is separate from the settings toggle: the user may have the
/// feature enabled but not currently showing the window.
final floatingWindowStateProvider = StateProvider<bool>((ref) => false);

/// Requests the system overlay permission required for the floating window.
///
/// Returns `true` if the permission was granted, `false` otherwise.
/// On platforms that do not require permission (e.g. desktop), this
/// catches the error and returns `true` so the feature degrades gracefully.
Future<bool> requestFloatingWindowPermission() async {
  try {
    final status = await Permission.systemAlertWindow.request();
    return status.isGranted;
  } catch (_) {
    // On unsupported platforms (desktop, web), assume permission is granted.
    return true;
  }
}

/// Enables the floating window: requests permission, then activates it.
///
/// Sets [floatingWindowStateProvider] to `true` on success.
/// Throws a [StateError] if the permission is denied.
Future<void> enableFloatingWindow(Ref ref) async {
  final granted = await requestFloatingWindowPermission();
  if (!granted) {
    throw StateError(
      'Overlay permission is required for the floating window. '
      'Please grant the permission in system settings.',
    );
  }
  ref.read(floatingWindowStateProvider.notifier).state = true;
}

/// Disables and hides the floating window.
///
/// Sets [floatingWindowStateProvider] to `false`.
void disableFloatingWindow(Ref ref) {
  ref.read(floatingWindowStateProvider.notifier).state = false;
}

/// Sends a quick request from the floating window.
///
/// This is a lightweight function that builds an [ApiRequest] from the
/// given parameters and sends it via [RequestRepository.sendRequest].
/// It does **not** go through the full request form or save the request
/// to the repository.
///
/// Returns the [ApiResponse] or throws on network errors.
Future<ApiResponse> sendQuickRequest({
  required String workspaceId,
  required String method,
  required String url,
  String? body,
  Map<String, String>? headers,
  int timeoutSeconds = 30,
  bool verifySsl = true,
}) async {
  final repo = getIt<RequestRepository>();

  // Map simple string headers to KeyValueItems for the request entity.
  final headerItems = headers?.entries
      .map(
        (e) => KeyValueItem(
          key: e.key,
          value: e.value,
          isEnabled: true,
          id: '', // Not persisted – empty ID is fine for transient requests.
        ),
      )
      .toList();

  final now = DateTime.now();
  final request = ApiRequest(
    id: '',
    workspaceId: workspaceId,
    name: 'Quick Request',
    method: _parseMethod(method),
    url: url,
    headers: headerItems ?? [],
    bodyContent: body ?? '',
    timeoutSeconds: timeoutSeconds,
    verifySsl: verifySsl,
    createdAt: now,
    updatedAt: now,
  );

  return repo.sendRequest(request);
}

/// Parses a method string (e.g. "GET", "POST") into [HttpMethod].
///
/// Falls back to [HttpMethod.get] for unrecognised values.
HttpMethod _parseMethod(String method) {
  return HttpMethod.values.firstWhere(
    (m) => m.name.toUpperCase() == method.toUpperCase(),
    orElse: () => HttpMethod.get,
  );
}