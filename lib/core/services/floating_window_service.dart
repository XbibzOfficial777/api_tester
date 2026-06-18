/// @file floating_window_service.dart
/// @brief Stub service for floating window (system_alert_window removed for v2 embedding compatibility).

library;

import 'package:dio/dio.dart';

/// Stub: SystemAlertWindow is not available (v1 embedding removed in Flutter 3.24).
/// All methods are no-ops. Re-enable when package supports v2 embedding.
class SystemAlertWindow {
  static Future<void> registerSystemAlertWindowCallback({
    required void Function() onWindowClick,
  }) async {}
}

/// Floating window service stub - all operations are no-ops.
class FloatingWindowService {
  static final FloatingWindowService instance = FloatingWindowService._();
  FloatingWindowService._();

  Future<bool> checkPermission() async => false;
  Future<void> requestPermission() async {}
  Future<void> showBubble() async {}
  Future<void> hideBubble() async {}
  Future<void> updateBubble(String title, String body) async {}
  Future<void> closeBubble() async {}
  Future<void> showPanel() async {}
  Future<void> closePanel() async {}
  Future<String?> sendQuickRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) async {
    try {
      final dio = Dio();
      final response = await dio.request(
        url,
        options: Options(method: method, headers: headers, sendTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)),
        data: body,
      );
      return response.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }
}