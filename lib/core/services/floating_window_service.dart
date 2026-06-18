/// @file floating_window_service.dart
/// @brief Service that manages the system overlay floating window.
///
/// Handles permission checking, window creation/updating/closing, and quick
/// API requests from the floating overlay. Uses [SystemAlertWindow] to show
/// native system-overlay windows on Android and falls back gracefully on
/// other platforms.
///
/// **Platform notes:**
/// - **Android**: Full support via `SYSTEM_ALERT_WINDOW` permission. The user
///   must grant "draw over other apps" permission from system settings.
/// - **iOS**: The `system_alert_window` package has **very limited** iOS
///   support. iOS does not allow true system-wide overlays. On iOS this
///   service will log a warning and all overlay operations become no-ops.
///   Consider using a Picture-in-Picture (PiP) approach for iOS if needed.
/// - **Desktop / Web**: Not supported. All operations degrade gracefully.

library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:system_alert_window/system_alert_window.dart';

/// Service that manages the system overlay floating window.
///
/// Handles permission checking, window creation, and quick API requests.
/// Implemented as a singleton to ensure a single source of truth for the
/// overlay state across the application.
///
/// Example usage:
/// ```dart
/// final service = FloatingWindowService.instance;
/// final hasPermission = await service.checkPermission();
/// if (hasPermission) {
///   await service.showBubble();
/// }
/// ```
class FloatingWindowService {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  /// Private constructor for the singleton pattern.
  FloatingWindowService._();

  /// The singleton instance of [FloatingWindowService].
  static final FloatingWindowService _instance = FloatingWindowService._();

  /// Provides access to the singleton [FloatingWindowService] instance.
  static FloatingWindowService get instance => _instance;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// The currently selected HTTP method in the floating window.
  ///
  /// Tracked in-memory because the native overlay communicates back via a
  /// callback that carries only the click event tag/ID.
  String _currentMethod = 'GET';

  /// The last URL entered in the floating window.
  String _currentUrl = '';

  /// Whether the overlay is currently visible.
  bool _isShowing = false;

  /// Whether [registerCallback] has already been called.
  bool _isCallbackRegistered = false;

  /// The HTTP methods available in the floating window dropdown.
  static const List<String> supportedMethods = ['GET', 'POST', 'PUT', 'DELETE'];

  /// Colour map for HTTP methods used in the overlay.
  static const Map<String, int> _methodColorValues = {
    'GET': 0xFF43A047,
    'POST': 0xFF1E88E5,
    'PUT': 0xFFFB8C00,
    'DELETE': 0xFFE53935,
  };

  // ---------------------------------------------------------------------------
  // Permission management
  // ---------------------------------------------------------------------------

  /// Checks whether the system overlay ("draw over other apps") permission
  /// is currently granted.
  ///
  /// On Android, this queries the `Permission.systemAlertWindow` status.
  /// On other platforms (iOS, desktop, web) this returns `true` so that
  /// callers can attempt to show the overlay without errors, even though
  /// it may be a no-op on unsupported platforms.
  ///
  /// Returns `true` if the permission is granted or the platform does not
  /// require it.
  Future<bool> checkPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      return status.isGranted;
    } catch (_) {
      // Unsupported platform — degrade gracefully.
      return true;
    }
  }

  /// Requests the system overlay permission.
  ///
  /// On Android, this opens the system settings page where the user can
  /// manually grant the "draw over other apps" permission. This permission
  /// **cannot** be granted programmatically — the user must toggle it in
  /// system settings.
  ///
  /// After the user returns from settings, [checkPermission] should be
  /// called again to verify the result.
  ///
  /// Returns `true` if the permission is now granted, `false` otherwise.
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.systemAlertWindow.request();
      return status.isGranted;
    } catch (_) {
      // Unsupported platform.
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // Window lifecycle
  // ---------------------------------------------------------------------------

  /// Shows the floating bubble overlay on screen.
  ///
  /// The bubble is a small circular overlay that the user can tap to expand
  /// into the full floating panel. This method builds the overlay using the
  /// native [SystemAlertWindow] plugin's declarative row/column API.
  ///
  /// Calling this when the overlay is already visible is a no-op.
  ///
  /// Throws a [StateError] if the overlay permission has not been granted.
  Future<void> showBubble() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) {
      throw StateError(
        'System overlay permission is not granted. '
        'Call requestPermission() first.',
      );
    }

    if (_isShowing) return;

    try {
      await SystemAlertWindow().showSystemWindow(
        height: 160,
        width: 160,
        gravity: SystemAlertWindowGravity.bottomRight,
        margin: const Margin(bottom: 100, right: 20),
        padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
        isFlagModal: false,
        header: SystemHeader(
          title: '',
          padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
          decoration: BoxDecoration(color: Colors.transparent),
        ),
        body: SystemBody(
          rows: [
            EachRow(
              columns: [
                EachColumn(
                  text: 'API',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  textColor: Colors.white,
                  alignment: Alignment.center,
                  flex: 1,
                ),
              ],
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(80),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const Padding(left: 0, top: 30, right: 0, bottom: 30),
              margin: const Margin(left: 0, top: 0, right: 0, bottom: 0),
              height: 160,
              tag: 'bubble',
            ),
          ],
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(80),
          ),
          padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
        ),
        footer: SystemFooter(
          padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
          decoration: BoxDecoration(color: Colors.transparent),
          buttons: [],
        ),
      );

      _isShowing = true;

      // Register the callback once, the first time the window is shown.
      if (!_isCallbackRegistered) {
        registerCallback();
        _isCallbackRegistered = true;
      }
    } on PlatformException catch (e) {
      // Log the error for debugging — the overlay may not be supported
      // on the current platform or Android version.
      // ignore: avoid_print
      print('[FloatingWindowService] Failed to show bubble: ${e.message}');
      rethrow;
    }
  }

  /// Hides the floating bubble overlay.
  ///
  /// Closes any currently visible system window created by this service.
  /// Safe to call even if no window is currently showing.
  Future<void> hideBubble() async {
    try {
      await SystemAlertWindow().closeSystemWindow();
      _isShowing = false;
    } on PlatformException catch (e) {
      // Log and swallow — the window may already be closed.
      // ignore: avoid_print
      print('[FloatingWindowService] Failed to hide bubble: ${e.message}');
    }
  }

  /// Expands the floating bubble into the full panel view.
  ///
  /// Replaces the small bubble with a wider panel containing a method
  /// selector, URL input, send button, and response preview area.
  Future<void> _showExpandedPanel() async {
    try {
      await SystemAlertWindow().updateSystemWindow(
        height: 520,
        width: 400,
        gravity: SystemAlertWindowGravity.bottomRight,
        margin: const Margin(bottom: 40, right: 16, left: 16, top: 40),
        padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
        isFlagModal: false,
        header: _buildPanelHeader(),
        body: SystemBody(
          rows: _buildPanelRows(),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          padding: const Padding(left: 12, top: 8, right: 12, bottom: 12),
        ),
        footer: SystemFooter(
          padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
          decoration: BoxDecoration(color: Colors.transparent),
          buttons: [],
        ),
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[FloatingWindowService] Failed to expand panel: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Panel builders
  // ---------------------------------------------------------------------------

  /// Builds the [SystemHeader] for the expanded floating panel.
  SystemHeader _buildPanelHeader() {
    return const SystemHeader(
      title: 'API Tester',
      titleTextStyle: TextStyle(
        fontSize: 15,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      padding: Padding(left: 16, top: 12, right: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF1A73E8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
    );
  }

  /// Builds the row definitions for the expanded floating panel.
  ///
  /// Each row represents a section of the panel UI:
  /// 1. Method selector buttons (GET, POST, PUT, DELETE)
  /// 2. URL input field
  /// 3. Action buttons (Send, Open App, Close)
  /// 4. Response status display
  /// 5. Response body preview
  List<EachRow> _buildPanelRows({String statusText = 'Status: ---', String responseBody = 'Response will appear here...'}) {
    return [
      // Row 1: Method selector
      _buildMethodSelectorRow(),
      // Row 2: URL input
      _buildUrlInputRow(),
      // Row 3: Action buttons
      _buildActionButtonsRow(),
      // Row 4: Response status
      _buildStatusRow(statusText),
      // Row 5: Response body preview
      _buildBodyPreviewRow(responseBody),
    ];
  }

  /// Builds the method selector row with coloured buttons for each HTTP method.
  EachRow _buildMethodSelectorRow() {
    final columns = supportedMethods.map((method) {
      final colorValue = _methodColorValues[method] ?? 0xFF78909C;
      final isSelected = method == _currentMethod;
      return EachColumn(
        text: '  $method  ',
        fontWeight: FontWeight.bold,
        fontSize: 12,
        textColor: isSelected ? Colors.white : Color(colorValue),
        alignment: Alignment.center,
        flex: 1,
        decoration: BoxDecoration(
          color: isSelected ? Color(colorValue) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(6),
        ),
        margin: const Margin(left: 2, top: 4, right: 2, bottom: 4),
        tag: 'method_$method',
      );
    }).toList();

    return EachRow(
      columns: columns,
      decoration: const BoxDecoration(color: Colors.transparent),
      padding: const Padding(left: 0, top: 0, right: 0, bottom: 4),
    );
  }

  /// Builds the URL input row with a styled text field.
  EachRow _buildUrlInputRow() {
    return EachRow(
      columns: [
        EachColumn(
          text: _currentUrl.isNotEmpty ? _currentUrl : 'https://api.example.com/endpoint',
          fontSize: 13,
          textColor: const Color(0xFF424242),
          alignment: Alignment.centerLeft,
          flex: 1,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBDBDBD), width: 1),
          ),
          padding: const Padding(left: 12, top: 10, right: 12, bottom: 10),
          margin: const Margin(left: 0, top: 4, right: 0, bottom: 4),
        ),
      ],
      decoration: const BoxDecoration(color: Colors.transparent),
    );
  }

  /// Builds the row containing the Send, Open App, and Close action buttons.
  EachRow _buildActionButtonsRow() {
    return EachRow(
      columns: [
        // Send button
        EachColumn(
          text: '  Send  ',
          fontWeight: FontWeight.bold,
          fontSize: 13,
          textColor: Colors.white,
          alignment: Alignment.center,
          flex: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF1A73E8),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const Padding(left: 8, top: 8, right: 8, bottom: 8),
          margin: const Margin(left: 0, top: 4, right: 4, bottom: 4),
          tag: 'send',
        ),
        // Open App button
        EachColumn(
          text: '  App  ',
          fontWeight: FontWeight.w600,
          fontSize: 12,
          textColor: const Color(0xFF1A73E8),
          alignment: Alignment.center,
          flex: 1,
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const Padding(left: 4, top: 8, right: 4, bottom: 8),
          margin: const Margin(left: 0, top: 4, right: 4, bottom: 4),
          tag: 'open_app',
        ),
        // Close button
        EachColumn(
          text: '  X  ',
          fontWeight: FontWeight.bold,
          fontSize: 13,
          textColor: const Color(0xFFE53935),
          alignment: Alignment.center,
          flex: 1,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const Padding(left: 4, top: 8, right: 4, bottom: 8),
          margin: const Margin(left: 0, top: 4, right: 0, bottom: 4),
          tag: 'close',
        ),
      ],
      decoration: const BoxDecoration(color: Colors.transparent),
    );
  }

  /// Builds the response status row.
  ///
  /// [text] — The status text to display (e.g. "200 OK" or "Error").
  EachRow _buildStatusRow(String text) {
    // Determine colour from the first character of the status text.
    Color statusColor = const Color(0xFF757575);
    if (text.startsWith('2')) {
      statusColor = const Color(0xFF43A047);
    } else if (text.startsWith('3')) {
      statusColor = const Color(0xFF1E88E5);
    } else if (text.startsWith('4')) {
      statusColor = const Color(0xFFFB8C00);
    } else if (text.startsWith('5')) {
      statusColor = const Color(0xFFE53935);
    }

    final bool isDefaultStatus = text == 'Status: ---';

    return EachRow(
      columns: [
        EachColumn(
          text: '  $text',
          fontSize: 12,
          textColor: isDefaultStatus ? const Color(0xFF757575) : statusColor,
          alignment: Alignment.centerLeft,
          flex: 1,
          fontWeight: isDefaultStatus ? FontWeight.normal : FontWeight.bold,
          decoration: BoxDecoration(
            color: isDefaultStatus
                ? const Color(0xFFFAFAFA)
                : statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const Padding(left: 8, top: 6, right: 8, bottom: 6),
          margin: const Margin(left: 0, top: 6, right: 0, bottom: 2),
        ),
      ],
      decoration: const BoxDecoration(color: Colors.transparent),
    );
  }

  /// Builds the response body preview row.
  ///
  /// [body] — The body text to display (should be pre-truncated).
  EachRow _buildBodyPreviewRow(String body) {
    return EachRow(
      columns: [
        EachColumn(
          text: body,
          fontSize: 11,
          textColor: body == 'Response will appear here...'
              ? const Color(0xFF9E9E9E)
              : const Color(0xFF424242),
          alignment: Alignment.topLeft,
          flex: 1,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const Padding(left: 10, top: 8, right: 10, bottom: 8),
          margin: const Margin(left: 0, top: 2, right: 0, bottom: 0),
          height: 120,
        ),
      ],
      decoration: const BoxDecoration(color: Colors.transparent),
    );
  }

  // ---------------------------------------------------------------------------
  // Window content updates
  // ---------------------------------------------------------------------------

  /// Updates the floating window to display a response status and body.
  ///
  /// This is called after a quick request completes (or fails). It
  /// refreshes the overlay UI to show the status code and a truncated
  /// preview of the response body.
  ///
  /// [status] — A formatted status string, e.g. `"200 OK"` or `"Error"`.
  /// [body] — The response body text (will be truncated for display).
  Future<void> updateWindow(String status, String body) async {
    if (!_isShowing) return;

    try {
      // Truncate body to roughly 300 characters for the overlay display.
      final truncatedBody = body.length > 300
          ? '${body.substring(0, 300)}\n...'
          : body;

      await SystemAlertWindow().updateSystemWindow(
        height: 520,
        width: 400,
        gravity: SystemAlertWindowGravity.bottomRight,
        margin: const Margin(bottom: 40, right: 16, left: 16, top: 40),
        padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
        isFlagModal: false,
        header: _buildPanelHeader(),
        body: SystemBody(
          rows: _buildPanelRows(
            statusText: status,
            responseBody: truncatedBody,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          padding: const Padding(left: 12, top: 8, right: 12, bottom: 12),
        ),
        footer: SystemFooter(
          padding: const Padding(left: 0, top: 0, right: 0, bottom: 0),
          decoration: BoxDecoration(color: Colors.transparent),
          buttons: [],
        ),
      );
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[FloatingWindowService] Failed to update window: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Quick API request
  // ---------------------------------------------------------------------------

  /// Sends a quick API request from the floating window.
  ///
  /// This method performs a real HTTP request using a standalone [Dio]
  /// instance with minimal configuration. It is designed to be called from
  /// the overlay callback when the user taps the "Send" button.
  ///
  /// A fresh Dio instance is used (instead of the shared one from the
  /// service locator) so that floating window requests are not affected by
  /// app-level interceptors, auth tokens, or retry policies that may
  /// interfere with quick, independent requests.
  ///
  /// [method] — The HTTP method (GET, POST, PUT, DELETE).
  /// [url] — The full request URL.
  /// [body] — Optional request body (typically JSON string for POST/PUT).
  /// [headers] — Optional map of additional request headers.
  ///
  /// Returns a map containing:
  /// - `'statusCode'` — The HTTP status code (int?), or `null` on error.
  /// - `'statusText'` — The status reason phrase (String).
  /// - `'body'` — The response body as a string.
  /// - `'responseTimeMs'` — The elapsed time in milliseconds.
  /// - `'error'` — Error message if the request failed, `null` otherwise.
  Future<Map<String, dynamic>> sendQuickRequest({
    required String method,
    required String url,
    String? body,
    Map<String, String>? headers,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          if (body != null) 'Content-Type': 'application/json; charset=utf-8',
          ...?headers,
        },
        validateStatus: (status) => status != null && status < 600,
      ));

      final response = await dio.request<dynamic>(
        url,
        data: body,
        options: Options(method: method),
      );

      stopwatch.stop();

      final responseBody = response.data is String
          ? response.data as String
          : jsonEncode(response.data);

      return {
        'statusCode': response.statusCode,
        'statusText': response.statusMessage ?? '',
        'body': responseBody,
        'responseTimeMs': stopwatch.elapsedMilliseconds,
        'error': null,
      };
    } on DioException catch (e) {
      stopwatch.stop();

      final statusCode = e.response?.statusCode;
      final rawBody = e.response?.data;

      final errorBody = rawBody is String
          ? rawBody
          : rawBody != null
              ? jsonEncode(rawBody)
              : '';

      return {
        'statusCode': statusCode,
        'statusText': e.response?.statusMessage ?? '',
        'body': errorBody,
        'responseTimeMs': stopwatch.elapsedMilliseconds,
        'error': _mapDioError(e),
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'statusCode': null,
        'statusText': '',
        'body': '',
        'responseTimeMs': stopwatch.elapsedMilliseconds,
        'error': 'Unexpected error: $e',
      };
    }
  }

  /// Maps a [DioException] to a human-readable error string.
  static String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout';
      case DioExceptionType.badResponse:
        return 'Server error: ${e.response?.statusCode} ${e.response?.statusMessage ?? ''}';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error — check your network';
      case DioExceptionType.badCertificate:
        return 'SSL certificate error';
      case DioExceptionType.unknown:
        return 'Error: ${e.message ?? e.error.toString()}';
    }
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Opens the main application from the floating window.
  ///
  /// On Android, closing the overlay causes the app's main activity to
  /// naturally come back to the foreground since it remains in the task
  /// stack.
  ///
  /// On unsupported platforms this is a no-op.
  Future<void> openMainApp() async {
    try {
      await hideBubble();
      await SystemAlertWindow().closeSystemWindow();
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('[FloatingWindowService] Failed to open main app: ${e.message}');
    }
  }

  // ---------------------------------------------------------------------------
  // Callback registration
  // ---------------------------------------------------------------------------

  /// Registers the system alert window click callback to handle user
  /// interactions from the native overlay.
  ///
  /// The callback processes tap events and dispatches them to the
  /// appropriate handler:
  ///
  /// - **`bubble`**: Expands the bubble into the full panel.
  /// - **`method_GET` / `method_POST` / `method_PUT` / `method_DELETE`**:
  ///   Updates the selected HTTP method and refreshes the panel.
  /// - **`send`**: Sends a quick API request with the current method and URL.
  /// - **`open_app`**: Closes the overlay and brings the main app to front.
  /// - **`close`**: Hides the floating window entirely.
  ///
  /// This method should be called once. Subsequent calls are idempotent
  /// because the plugin only retains the last registered callback.
  ///
  /// **Note on iOS:** On iOS the system alert window is not supported, so
  /// this callback will never be invoked. Consider using Picture-in-Picture
  /// or CallKit-based approaches for iOS overlay functionality.
  void registerCallback() {
    SystemAlertWindow().setSystemWindowOnClickListener((tag) async {
      await _handleCallback(tag);
    });
  }

  /// Processes a callback [tag] from the native overlay.
  ///
  /// The tag string identifies which UI element was tapped. Tags are set
  /// via the `tag` property on [EachColumn] or [EachRow] instances when
  /// building the panel rows.
  Future<void> _handleCallback(String tag) async {
    // ignore: avoid_print
    print('[FloatingWindowService] Callback received: $tag');

    // Method selection buttons: "method_GET", "method_POST", etc.
    if (tag.startsWith('method_')) {
      final methodName = tag.replaceFirst('method_', '').toUpperCase();
      if (supportedMethods.contains(methodName)) {
        _currentMethod = methodName;
        await _showExpandedPanel();
      }
      return;
    }

    switch (tag) {
      case 'bubble':
        // Bubble was tapped — expand to the full panel.
        await _showExpandedPanel();

      case 'send':
        // Send a quick request with the current method and URL.
        await _performQuickRequest();

      case 'open_app':
        await openMainApp();

      case 'close':
        await hideBubble();

      default:
        // ignore: avoid_print
        print('[FloatingWindowService] Unknown callback tag: $tag');
    }
  }

  /// Performs a quick API request from the overlay and updates the display.
  ///
  /// Uses the currently selected method and URL. Falls back to a
  /// placeholder URL if none has been set. Updates the floating window
  /// with the response status and body when the request completes.
  Future<void> _performQuickRequest() async {
    // Show "Sending..." state immediately.
    await updateWindow('Sending...', 'Request in progress...');

    final url = _currentUrl.isNotEmpty
        ? _currentUrl
        : 'https://jsonplaceholder.typicode.com/posts/1';

    final result = await sendQuickRequest(
      method: _currentMethod,
      url: url,
    );

    final statusCode = result['statusCode'];
    final statusText = result['statusText'] as String;
    final body = result['body'] as String;
    final error = result['error'] as String?;

    if (error != null) {
      await updateWindow(
        'Error: $error',
        body.isNotEmpty ? body : 'No response received.',
      );
    } else {
      await updateWindow(
        '$statusCode $statusText',
        body,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Public state accessors
  // ---------------------------------------------------------------------------

  /// Whether the floating window is currently visible on screen.
  bool get isShowing => _isShowing;

  /// The currently selected HTTP method in the floating window.
  String get currentMethod => _currentMethod;

  /// Sets the current HTTP method for the floating window.
  ///
  /// Only accepts values in [supportedMethods]. Invalid values are ignored.
  set currentMethod(String value) {
    if (supportedMethods.contains(value.toUpperCase())) {
      _currentMethod = value.toUpperCase();
    }
  }

  /// The last URL used in the floating window.
  String get currentUrl => _currentUrl;

  /// Sets the URL for the next floating window request.
  set currentUrl(String value) {
    _currentUrl = value;
  }
}