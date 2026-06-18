/// @file websocket_screen.dart
/// @brief Tool screen for testing WebSocket connections.
///
/// Provides a live WebSocket client with URL input, connect/disconnect
/// controls, a scrollable message log with colour-coded sent/received/system
/// messages, a message input with send button, format selection, auto-scroll
/// toggle, and configurable ping/pong interval.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/theme/app_theme.dart';
import '../../widgets/common/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Message Types
// ---------------------------------------------------------------------------

/// The type of a WebSocket message in the log.
enum _WsMessageType {
  /// A message sent by the user.
  sent,

  /// A message received from the server.
  received,

  /// A system event (connected, disconnected, error).
  system,
}

/// A single entry in the WebSocket message log.
class _WsMessage {
  /// The message type.
  final _WsMessageType type;

  /// The message content.
  final String text;

  /// The timestamp when this message was logged.
  final DateTime timestamp;

  /// Creates a [_WsMessage].
  const _WsMessage({
    required this.type,
    required this.text,
    required this.timestamp,
  });
}

// ---------------------------------------------------------------------------
// Connection State
// ---------------------------------------------------------------------------

/// The current WebSocket connection state.
enum _WsConnectionState {
  /// Not connected.
  disconnected,

  /// Attempting to connect.
  connecting,

  /// Connected and ready.
  connected,

  /// Connection failed with an error.
  error,
}

// ---------------------------------------------------------------------------
// State Notifier
// ---------------------------------------------------------------------------

/// Manages the WebSocket connection, message log, and settings.
class _WebSocketNotifier extends StateNotifier<_WsState> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;

  _WebSocketNotifier() : super(_WsState());

  /// Connects to the given WebSocket URL.
  Future<void> connect(String url) async {
    if (url.trim().isEmpty) return;
    final wsUrl = url.trim();

    state = state.copyWith(
      connectionState: _WsConnectionState.connecting,
      url: wsUrl,
    );

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Wait for the connection to be ready.
      await _channel!.ready;

      state = state.copyWith(
        connectionState: _WsConnectionState.connected,
        messages: [
          ...state.messages,
          _WsMessage(
            type: _WsMessageType.system,
            text: 'Connected to $wsUrl',
            timestamp: DateTime.now(),
          ),
        ],
      );

      // Listen for incoming messages.
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      // Start ping timer if configured.
      _startPingTimer();
    } catch (e) {
      state = state.copyWith(
        connectionState: _WsConnectionState.error,
        messages: [
          ...state.messages,
          _WsMessage(
            type: _WsMessageType.system,
            text: 'Connection failed: $e',
            timestamp: DateTime.now(),
          ),
        ],
      );
    }
  }

  /// Disconnects from the WebSocket server.
  void disconnect() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;

    state = state.copyWith(
      connectionState: _WsConnectionState.disconnected,
      messages: [
        ...state.messages,
        _WsMessage(
          type: _WsMessageType.system,
          text: 'Disconnected',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  /// Sends a text message over the WebSocket connection.
  void send(String message) {
    if (_channel == null ||
        state.connectionState != _WsConnectionState.connected) return;

    final formattedMessage = state.formatJson
        ? _tryFormatJson(message)
        : message;

    _channel!.sink.add(formattedMessage);

    state = state.copyWith(
      messages: [
        ...state.messages,
        _WsMessage(
          type: _WsMessageType.sent,
          text: formattedMessage,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  /// Clears the message log.
  void clearLog() {
    state = state.copyWith(messages: []);
  }

  /// Sets the auto-scroll toggle.
  void setAutoScroll(bool value) {
    state = state.copyWith(autoScroll: value);
  }

  /// Sets the message format (text or JSON).
  void setFormat(bool isJson) {
    state = state.copyWith(formatJson: isJson);
  }

  /// Sets the ping interval in seconds (0 to disable).
  void setPingInterval(int seconds) {
    state = state.copyWith(pingIntervalSeconds: seconds);
    _restartPingTimer();
  }

  /// Handles an incoming message from the WebSocket.
  void _onMessage(dynamic data) {
    final text = data.toString();
    state = state.copyWith(
      messages: [
        ...state.messages,
        _WsMessage(
          type: _WsMessageType.received,
          text: text,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  /// Handles a WebSocket error.
  void _onError(Object error) {
    state = state.copyWith(
      connectionState: _WsConnectionState.error,
      messages: [
        ...state.messages,
        _WsMessage(
          type: _WsMessageType.system,
          text: 'Error: $error',
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  /// Handles WebSocket close / done event.
  void _onDone() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;

    if (state.connectionState == _WsConnectionState.connected) {
      state = state.copyWith(
        connectionState: _WsConnectionState.disconnected,
        messages: [
          ...state.messages,
          _WsMessage(
            type: _WsMessageType.system,
            text: 'Connection closed by server',
            timestamp: DateTime.now(),
          ),
        ],
      );
    }
  }

  /// Starts the periodic ping timer.
  void _startPingTimer() {
    _pingTimer?.cancel();
    final interval = state.pingIntervalSeconds;
    if (interval <= 0) return;

    _pingTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) {
        if (_channel != null &&
            state.connectionState == _WsConnectionState.connected) {
          // WebSocket ping frames are handled at the protocol level.
          // Some servers expect a custom ping message.
          _channel!.sink.add('__ping__');
          state = state.copyWith(
            messages: [
              ...state.messages,
              _WsMessage(
                type: _WsMessageType.system,
                text: 'Ping sent',
                timestamp: DateTime.now(),
              ),
            ],
          );
        }
      },
    );
  }

  /// Restarts the ping timer (e.g. after interval change).
  void _restartPingTimer() {
    if (state.connectionState == _WsConnectionState.connected) {
      _startPingTimer();
    }
  }

  /// Attempts to pretty-print a JSON string. Returns the original if it
  /// is not valid JSON.
  String _tryFormatJson(String input) {
    try {
      final decoded = json.decode(input);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return input;
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the WebSocket screen.
class _WsState {
  /// The current connection state.
  final _WsConnectionState connectionState;

  /// The WebSocket URL being connected to.
  final String url;

  /// The list of logged messages.
  final List<_WsMessage> messages;

  /// Whether to auto-scroll the message log to the bottom.
  final bool autoScroll;

  /// Whether to format outgoing/incoming messages as JSON.
  final bool formatJson;

  /// Ping interval in seconds (0 = disabled).
  final int pingIntervalSeconds;

  const _WsState({
    this.connectionState = _WsConnectionState.disconnected,
    this.url = '',
    this.messages = const [],
    this.autoScroll = true,
    this.formatJson = false,
    this.pingIntervalSeconds = 0,
  });

  _WsState copyWith({
    _WsConnectionState? connectionState,
    String? url,
    List<_WsMessage>? messages,
    bool? autoScroll,
    bool? formatJson,
    int? pingIntervalSeconds,
  }) {
    return _WsState(
      connectionState: connectionState ?? this.connectionState,
      url: url ?? this.url,
      messages: messages ?? this.messages,
      autoScroll: autoScroll ?? this.autoScroll,
      formatJson: formatJson ?? this.formatJson,
      pingIntervalSeconds:
          pingIntervalSeconds ?? this.pingIntervalSeconds,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _wsProvider =
    StateNotifierProvider<_WebSocketNotifier, _WsState>(
  (ref) => _WebSocketNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Provides a live WebSocket client with message send/receive capability.
///
/// Features:
/// - URL input with ws:// and wss:// protocol support.
/// - Connect / Disconnect button with state indicator.
/// - Scrollable message log with colour-coded messages.
/// - Message input + Send button.
/// - Format selector (Text / JSON).
/// - Auto-scroll toggle.
/// - Ping interval configuration.
/// - Clear log button.
class WebSocketScreen extends ConsumerStatefulWidget {
  /// Creates a [WebSocketScreen].
  const WebSocketScreen({super.key});

  @override
  ConsumerState<WebSocketScreen> createState() => _WebSocketScreenState();
}

class _WebSocketScreenState extends ConsumerState<WebSocketScreen> {
  final _urlController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _urlController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Auto-scrolls to the bottom of the message log.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  /// Toggles the WebSocket connection.
  void _toggleConnection() {
    final wsState = ref.read(_wsProvider);
    if (wsState.connectionState == _WsConnectionState.connected) {
      ref.read(_wsProvider.notifier).disconnect();
    } else {
      ref.read(_wsProvider.notifier).connect(_urlController.text);
    }
  }

  /// Sends the message from the input field.
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    ref.read(_wsProvider.notifier).send(text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final wsState = ref.watch(_wsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isConnected =
        wsState.connectionState == _WsConnectionState.connected;
    final isConnecting =
        wsState.connectionState == _WsConnectionState.connecting;

    // Auto-scroll when new messages arrive.
    ref.listen<_WsState>(_wsProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length &&
          next.autoScroll) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket'),
        actions: [
          // Connection status indicator.
          _ConnectionStatusBadge(state: wsState.connectionState),
          const SizedBox(width: 8),

          // Clear log.
          IconButton(
            icon: const Icon(Symbols.delete_sweep, size: 20),
            tooltip: 'Clear log',
            onPressed:
                wsState.messages.isNotEmpty ? () => ref.read(_wsProvider.notifier).clearLog() : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- URL Input ---
          Container(
            padding: const EdgeInsets.all(12),
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'wss://echo.websocket.org',
                      labelText: 'WebSocket URL',
                      isDense: true,
                      prefixIcon: const Icon(Symbols.link, size: 18),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    enabled: !isConnected && !isConnecting,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isConnecting ? null : _toggleConnection,
                  icon: isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isConnected
                              ? Symbols.link_off
                              : Symbols.link,
                          size: 18,
                        ),
                  label: Text(isConnecting
                      ? 'Connecting…'
                      : isConnected
                          ? 'Disconnect'
                          : 'Connect'),
                ),
              ],
            ),
          ),

          // --- Settings Bar ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Format toggle.
                FilterChip(
                  label: const Text('JSON', style: TextStyle(fontSize: 11)),
                  selected: wsState.formatJson,
                  onSelected: (v) =>
                      ref.read(_wsProvider.notifier).setFormat(v),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),

                // Auto-scroll toggle.
                FilterChip(
                  label: const Text('Auto-scroll',
                      style: TextStyle(fontSize: 11)),
                  selected: wsState.autoScroll,
                  onSelected: (v) =>
                      ref.read(_wsProvider.notifier).setAutoScroll(v),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),

                // Ping interval.
                Text('Ping:',
                    style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant)),
                const SizedBox(width: 4),
                SizedBox(
                  width: 50,
                  child: DropdownButtonFormField<int>(
                    value: wsState.pingIntervalSeconds,
                    isDense: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Off', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 15, child: Text('15s', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 30, child: Text('30s', style: TextStyle(fontSize: 11))),
                      DropdownMenuItem(value: 60, child: Text('60s', style: TextStyle(fontSize: 11))),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(_wsProvider.notifier).setPingInterval(v);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // --- Message Log ---
          Expanded(
            child: wsState.messages.isEmpty
                ? Center(
                    child: EmptyStateWidget(
                      icon: Symbols.chat,
                      title: 'No Messages',
                      subtitle: isConnected
                          ? 'Send a message to get started.'
                          : 'Connect to a WebSocket server to begin.',
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: wsState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = wsState.messages[index];
                      return _MessageBubble(message: msg);
                    },
                  ),
          ),

          const Divider(height: 1),

          // --- Message Input ---
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message…',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 14),
                    enabled: isConnected,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: isConnected ? _sendMessage : null,
                  icon: const Icon(Symbols.send, size: 18),
                  label: const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connection Status Badge
// ---------------------------------------------------------------------------

/// A small coloured dot indicating the WebSocket connection state.
class _ConnectionStatusBadge extends StatelessWidget {
  /// The current connection state.
  final _WsConnectionState state;

  const _ConnectionStatusBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color color;
    String label;

    switch (state) {
      case _WsConnectionState.connected:
        color = AppTheme.status2xx;
        label = 'Connected';
        break;
      case _WsConnectionState.connecting:
        color = AppTheme.status3xx;
        label = 'Connecting';
        break;
      case _WsConnectionState.error:
        color = AppTheme.status5xx;
        label = 'Error';
        break;
      case _WsConnectionState.disconnected:
        color = colorScheme.outline;
        label = 'Disconnected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: textTheme.labelSmall?.copyWith(
                  color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message Bubble
// ---------------------------------------------------------------------------

/// A single message bubble in the WebSocket message log.
class _MessageBubble extends StatelessWidget {
  /// The message to display.
  final _WsMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // System messages are centered and muted.
    if (message.type == _WsMessageType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final isSent = message.type == _WsMessageType.sent;
    final time =
        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}:${message.timestamp.second.toString().padLeft(2, '0')}';

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isSent
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isSent ? const Radius.circular(12) : Radius.zero,
            bottomRight: isSent ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}