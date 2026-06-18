/// @file jwt_decoder_screen.dart
/// @brief Standalone tool screen for decoding and inspecting JWT tokens.
///
/// Provides a large text input for JWT tokens, auto-detect on paste,
/// formatted display of the decoded header, payload, and signature
/// sections, expiration status with countdown, and copy buttons for
/// individual sections.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/tools/jwt_decoder.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the JWT decoder screen.
class _JwtState {
  /// Whether a decode operation is in progress.
  final bool isDecoding;

  /// The decoded JWT result, or null if not yet decoded.
  final JwtDecodeResult? result;

  /// Error message if decoding failed.
  final String? error;

  /// Timer ticks remaining for countdown display.
  final Duration? timeUntilExpiry;

  const _JwtState({
    this.isDecoding = false,
    this.result,
    this.error,
    this.timeUntilExpiry,
  });

  _JwtState copyWith({
    bool? isDecoding,
    JwtDecodeResult? result,
    String? error,
    Duration? timeUntilExpiry,
    bool clearError = false,
  }) {
    return _JwtState(
      isDecoding: isDecoding ?? this.isDecoding,
      result: result ?? this.result,
      error: clearError ? null : (error ?? this.error),
      timeUntilExpiry: timeUntilExpiry ?? this.timeUntilExpiry,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class _JwtNotifier extends StateNotifier<_JwtState> {
  _JwtNotifier() : super(const _JwtState());

  /// Decodes the given JWT token string.
  Future<void> decode(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;

    // Validate basic JWT structure before calling the use case.
    if (trimmed.split('.').length != 3) {
      state = state.copyWith(
        isDecoding: false,
        error: 'Invalid JWT format: expected three parts (header.payload.signature)',
      );
      return;
    }

    state = state.copyWith(
      isDecoding: true,
      clearError: true,
      result: null,
    );

    try {
      final decoder = JwtDecoder();
      final result = await decoder(JwtDecoderParams(token: trimmed));

      // Calculate time until expiry for countdown.
      Duration? timeUntilExpiry;
      if (result.payload.containsKey('exp')) {
        final expValue = result.payload['exp'];
        int expSeconds;
        if (expValue is int) {
          expSeconds = expValue;
        } else if (expValue is double) {
          expSeconds = expValue.toInt();
        } else {
          expSeconds = 0;
        }
        final expDate =
            DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
        final remaining = expDate.difference(DateTime.now());
        if (!remaining.isNegative) {
          timeUntilExpiry = remaining;
        }
      }

      state = state.copyWith(
        isDecoding: false,
        result: result,
        timeUntilExpiry: timeUntilExpiry,
      );
    } catch (e) {
      state = state.copyWith(
        isDecoding: false,
        error: 'Failed to decode: $e',
      );
    }
  }

  /// Updates the time-until-expiry countdown.
  void tickCountdown() {
    if (state.timeUntilExpiry == null || state.result == null) return;

    final expValue = state.result!.payload['exp'];
    if (expValue == null) return;

    int expSeconds;
    if (expValue is int) {
      expSeconds = expValue;
    } else if (expValue is double) {
      expSeconds = expValue.toInt();
    } else {
      return;
    }

    final expDate =
        DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
    final remaining = expDate.difference(DateTime.now());

    if (remaining.isNegative) {
      state = state.copyWith(timeUntilExpiry: Duration.zero);
    } else {
      state = state.copyWith(timeUntilExpiry: remaining);
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _jwtProvider =
    StateNotifierProvider<_JwtNotifier, _JwtState>(
  (ref) => _JwtNotifier(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Standalone JWT decoder accessible from the tools menu.
///
/// Features:
/// - Large text input for pasting a JWT token.
/// - Auto-detect on paste (triggers decode automatically).
/// - Decoded sections displayed in cards: Header, Payload, Signature.
/// - Expiration status with live countdown timer.
/// - Copy buttons for individual sections.
class JwtDecoderScreen extends ConsumerStatefulWidget {
  /// Creates a [JwtDecoderScreen].
  const JwtDecoderScreen({super.key});

  @override
  ConsumerState<JwtDecoderScreen> createState() => _JwtDecoderScreenState();
}

class _JwtDecoderScreenState extends ConsumerState<JwtDecoderScreen> {
  final _tokenController = TextEditingController();
  Timer? _countdownTimer;

  @override
  void dispose() {
    _tokenController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Called when the user pastes or changes the token text.
  void _onTokenChanged() {
    final token = _tokenController.text.trim();
    if (token.split('.').length == 3 && token.length > 20) {
      // Looks like a JWT – auto-decode.
      ref.read(_jwtProvider.notifier).decode(token);
    }
  }

  /// Starts a countdown timer for token expiration.
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => ref.read(_jwtProvider.notifier).tickCountdown(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jwtState = ref.watch(_jwtProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Start/stop countdown based on state.
    ref.listen<_JwtState>(_jwtProvider, (prev, next) {
      if (next.timeUntilExpiry != null && !next.result!.isExpired) {
        _startCountdown();
      } else if (prev?.timeUntilExpiry != null && next.timeUntilExpiry == null) {
        _countdownTimer?.cancel();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('JWT Decoder'),
        actions: [
          // Paste from clipboard.
          IconButton(
            icon: const Icon(Symbols.content_paste, size: 20),
            tooltip: 'Paste from clipboard',
            onPressed: () async {
              final data =
                  await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                _tokenController.text = data!.text!;
                _onTokenChanged();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Token Input ---
            Text(
              'Paste a JWT token to decode its header, payload, and inspect '
              'the signature.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'JWT Token',
                hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c',
                prefixIcon:
                    const Icon(Symbols.key, size: 20),
                border: const OutlineInputBorder(),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              onChanged: (_) => _onTokenChanged(),
            ),
            const SizedBox(height: 12),

            // --- Decode Button ---
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: jwtState.isDecoding
                    ? null
                    : () => ref
                        .read(_jwtProvider.notifier)
                        .decode(_tokenController.text),
                icon: jwtState.isDecoding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Symbols.lock_open, size: 18),
                label: Text(
                    jwtState.isDecoding ? 'Decoding…' : 'Decode Token'),
              ),
            ),

            const SizedBox(height: 16),

            // --- Error ---
            if (jwtState.error != null)
              Card(
                color: colorScheme.error.withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Symbols.error,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(jwtState.error!,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.error)),
                      ),
                    ],
                  ),
                ),
              ),

            // --- Decoded Result ---
            if (jwtState.result != null) ...[
              // Expiration Status Card.
              _buildExpirationCard(context, jwtState, colorScheme, textTheme),
              const SizedBox(height: 12),

              // Header Card.
              _buildDecodedSectionCard(
                context: context,
                title: 'Header',
                icon: Symbols.settings,
                content: const JsonEncoder.withIndent('  ')
                    .convert(jwtState.result!.header),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),

              // Payload Card.
              _buildDecodedSectionCard(
                context: context,
                title: 'Payload',
                icon: Symbols.description,
                content: const JsonEncoder.withIndent('  ')
                    .convert(jwtState.result!.payload),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),

              // Signature Card.
              _buildDecodedSectionCard(
                context: context,
                title: 'Signature',
                icon: Symbols.fingerprint,
                content: jwtState.result!.signature,
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(height: 12),

              // Key Claims Summary.
              _buildClaimsSummary(context, jwtState.result!.payload,
                  colorScheme, textTheme),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the expiration status card with live countdown.
  Widget _buildExpirationCard(
    BuildContext context,
    _JwtState jwtState,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final result = jwtState.result!;
    final isExpired = result.isExpired;
    final color = isExpired ? AppTheme.status5xx : AppTheme.status2xx;

    return Card(
      color: color.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isExpired ? Symbols.warning : Symbols.check_circle,
                  color: color,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExpired ? 'EXPIRED' : 'VALID',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        result.expirationStatus,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Live countdown.
            if (jwtState.timeUntilExpiry != null && !isExpired) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.status2xx.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(jwtState.timeUntilExpiry!),
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.status2xx,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds a section card with copy functionality for decoded JWT parts.
  Widget _buildDecodedSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color:
                colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              children: [
                Icon(icon,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                // Copy button.
                IconButton(
                  icon: const Icon(Symbols.copy_all, size: 16),
                  tooltip: 'Copy $title',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title copied'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          // Content.
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a summary of common JWT claims.
  Widget _buildClaimsSummary(
    BuildContext context,
    Map<String, dynamic> payload,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final claims = <String, String>{};

    // Standard registered claims.
    if (payload.containsKey('sub')) {
      claims['Subject (sub)'] = payload['sub'].toString();
    }
    if (payload.containsKey('iss')) {
      claims['Issuer (iss)'] = payload['iss'].toString();
    }
    if (payload.containsKey('aud')) {
      claims['Audience (aud)'] = payload['aud'].toString();
    }
    if (payload.containsKey('iat')) {
      final iat = payload['iat'];
      final dt = iat is int
          ? DateTime.fromMillisecondsSinceEpoch(iat * 1000).toUtc()
          : null;
      claims['Issued At (iat)'] =
          dt?.toIso8601String() ?? iat.toString();
    }
    if (payload.containsKey('exp')) {
      final exp = payload['exp'];
      final dt = exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000).toUtc()
          : null;
      claims['Expires At (exp)'] =
          dt?.toIso8601String() ?? exp.toString();
    }
    if (payload.containsKey('nbf')) {
      final nbf = payload['nbf'];
      final dt = nbf is int
          ? DateTime.fromMillisecondsSinceEpoch(nbf * 1000).toUtc()
          : null;
      claims['Not Before (nbf)'] =
          dt?.toIso8601String() ?? nbf.toString();
    }
    if (payload.containsKey('jti')) {
      claims['JWT ID (jti)'] = payload['jti'].toString();
    }

    if (claims.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Claims',
                style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...claims.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(e.key,
                            style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant)),
                      ),
                      Expanded(
                        child: SelectableText(e.value,
                            style: textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace')),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  /// Formats a [Duration] as HH:MM:SS.
  String _formatDuration(Duration duration) {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}