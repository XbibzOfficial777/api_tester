/// @file collection_runner_screen.dart
/// @brief Screen for running a collection of API requests sequentially.
///
/// Displays the collection name, a configuration panel (delay, stop-on-error),
/// start/stop/reset controls, a real-time progress indicator, and a scrollable
/// list of per-request results as they complete. A summary bar and JSON export
/// button appear after the run finishes. Tapping a result shows full
/// request/response details in a bottom sheet.

library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/core/extensions/string_extensions.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/assertion.dart';
import 'package:api_tester/domain/entities/collection.dart';
import 'package:api_tester/domain/entities/request_runner_result.dart';
import 'package:api_tester/domain/entities/runner_result.dart';
import 'package:api_tester/domain/repositories/collection_repository.dart';
import 'package:api_tester/domain/repositories/request_repository.dart';
import 'package:api_tester/presentation/providers/runner_provider.dart';
import 'package:api_tester/presentation/widgets/common/method_chip.dart';
import 'package:api_tester/presentation/widgets/common/status_code_badge.dart';
import 'package:api_tester/presentation/widgets/common/app_loading_indicator.dart';
import 'package:api_tester/presentation/widgets/common/error_widget.dart';

/// Executes all requests in a collection and displays aggregated results.
///
/// Requires a [collectionId] which is used to load the [Collection] entity
/// and all associated [ApiRequest]s from their respective repositories.
class CollectionRunnerScreen extends ConsumerStatefulWidget {
  /// ID of the collection to run.
  final String collectionId;

  /// Creates a [CollectionRunnerScreen].
  const CollectionRunnerScreen({super.key, required this.collectionId});

  @override
  ConsumerState<CollectionRunnerScreen> createState() =>
      _CollectionRunnerScreenState();
}

class _CollectionRunnerScreenState
    extends ConsumerState<CollectionRunnerScreen> {
  // ---------------------------------------------------------------------------
  // Local state
  // ---------------------------------------------------------------------------

  /// The loaded collection entity.
  Collection? _collection;

  /// All requests that belong to this collection, keyed by ID.
  Map<String, ApiRequest> _requests = {};

  /// Local delay override (ms). Mirrors [_collection] initially.
  int _delayMs = 0;

  /// Local stop-on-error override.
  bool _stopOnError = false;

  /// Whether the initial data is still loading.
  bool _isLoading = true;

  /// Error message if loading failed.
  String? _loadError;

  /// Controller for scrolling the results list automatically.
  final ScrollController _resultsScrollController = ScrollController();

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _resultsScrollController.dispose();
    super.dispose();
  }

  /// Loads the collection and its requests from the repository.
  Future<void> _loadData() async {
    try {
      final collectionRepo = getIt<CollectionRepository>();
      final requestRepo = getIt<RequestRepository>();

      final collection =
          await collectionRepo.getCollection(widget.collectionId);
      final requests =
          await requestRepo.getRequestsByCollection(widget.collectionId);

      final requestMap = <String, ApiRequest>{};
      for (final r in requests) {
        requestMap[r.id] = r;
      }

      if (mounted) {
        setState(() {
          _collection = collection;
          _requests = requestMap;
          _delayMs = collection.delayBetweenRequestsMs;
          _stopOnError = collection.stopOnError;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Starts the collection run with current configuration.
  void _startRun() {
    if (_collection == null) return;

    // Build a modified collection with the local config overrides.
    final config = _collection!.copyWith(
      delayBetweenRequestsMs: _delayMs,
      stopOnError: _stopOnError,
    );

    // Build the assertions map (empty for now – assertions are defined
    // per-request in a future iteration).
    final assertions = <String, List<Assertion>>{};

    ref.read(runnerStateProvider.notifier).runCollection(
          collection: config,
          requests: _requests,
          assertions: assertions,
        );
  }

  /// Cancels the current in-progress run.
  void _stopRun() {
    ref.read(runnerStateProvider.notifier).cancelRun();
  }

  /// Resets the runner state so the user can reconfigure and re-run.
  void _resetRun() {
    ref.read(runnerStateProvider.notifier).reset();
  }

  /// Exports the current results as a JSON file share.
  void _exportResults() {
    final runnerState = ref.read(runnerStateProvider);
    final result = runnerState.finalResult;
    if (result == null) return;

    final exportData = {
      'collectionId': _collection?.id,
      'collectionName': _collection?.name,
      'status': result.status.name,
      'totalRequests': result.totalRequests,
      'passedCount': result.passedCount,
      'failedCount': result.failedCount,
      'durationMs': result.durationMs,
      'startedAt': result.startedAt.toIso8601String(),
      'completedAt': result.completedAt?.toIso8601String(),
      'results': result.results.map((r) => {
            'requestName': r.requestName,
            'method': r.method,
            'url': r.url,
            'statusCode': r.statusCode,
            'responseTimeMs': r.responseTimeMs,
            'allAssertionsPassed': r.allAssertionsPassed,
            'error': r.error,
            'responseBody': r.responseBody,
            'assertions': r.assertions.map((a) => {
                  'type': a.type.name,
                  'expected': a.expectedValue,
                  'actual': a.actualValue,
                  'passed': a.passed,
                  'errorMessage': a.errorMessage,
                }).toList(),
          }).toList(),
    };

    final jsonString =
        const JsonEncoder.withIndent('  ').convert(exportData);

    // Copy to clipboard as a simple "export".
    Clipboard.setData(ClipboardData(text: jsonString));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Results copied to clipboard as JSON'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        title: Text(_collection?.name ?? 'Run Collection'),
        actions: [
          // Export button – only enabled after a run completes.
          Consumer(
            builder: (context, ref, _) {
              final runnerState = ref.watch(runnerStateProvider);
              return IconButton(
                icon: const Icon(Symbols.file_download),
                tooltip: 'Export results as JSON',
                onPressed: runnerState.finalResult != null
                    ? _exportResults
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const AppLoadingIndicator(message: 'Loading collection…')
          : _loadError != null
              ? AppErrorWidget(
                  message: 'Failed to load collection',
                  details: _loadError,
                  onRetry: _loadData,
                )
              : _buildBody(colorScheme, textTheme),
    );
  }

  /// Builds the main scrollable content area.
  Widget _buildBody(ColorScheme colorScheme, TextTheme textTheme) {
    final runnerState = ref.watch(runnerStateProvider);

    return Column(
      children: [
        // -----------------------------------------------------------------
        // Collection info + config panel
        // -----------------------------------------------------------------
        _buildConfigPanel(colorScheme, textTheme, runnerState),

        const Divider(height: 1),

        // -----------------------------------------------------------------
        // Progress bar (visible while running or completed).
        // -----------------------------------------------------------------
        if (runnerState.isRunning || runnerState.isComplete)
          _buildProgressBar(colorScheme, runnerState),

        // -----------------------------------------------------------------
        // Results list
        // -----------------------------------------------------------------
        Expanded(
          child: runnerState.results.isEmpty && !runnerState.isRunning
              ? _buildEmptyResults(colorScheme, textTheme)
              : ListView.builder(
                  controller: _resultsScrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: runnerState.results.length,
                  itemBuilder: (context, index) {
                    final result = runnerState.results[index];
                    return _buildResultCard(result, colorScheme, textTheme);
                  },
                ),
        ),

        // -----------------------------------------------------------------
        // Summary bar (visible after run completes).
        // -----------------------------------------------------------------
        if (runnerState.isComplete && runnerState.finalResult != null)
          _buildSummaryBar(colorScheme, textTheme, runnerState),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Config panel
  // ---------------------------------------------------------------------------

  /// Builds the configuration and control panel at the top of the screen.
  Widget _buildConfigPanel(
    ColorScheme colorScheme,
    TextTheme textTheme,
    RunnerState runnerState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collection name and request count.
          Row(
            children: [
              Icon(Symbols.play_circle, color: colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _collection?.name ?? 'Collection',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_collection?.requestIds.length ?? 0} request${(_collection?.requestIds.length ?? 0) != 1 ? 's' : ''}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Delay slider.
          Row(
            children: [
              Icon(Symbols.timer, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delay: ${_delayMs}ms',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          Slider(
            value: _delayMs.toDouble(),
            min: 0,
            max: 5000,
            divisions: 50,
            label: '${_delayMs}ms',
            onChanged: runnerState.isRunning
                ? null
                : (v) => setState(() => _delayMs = v.round()),
          ),

          // Stop on error toggle.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Stop on error', style: textTheme.bodyMedium),
            subtitle: Text(
              'Abort the run if any request fails',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            value: _stopOnError,
            onChanged: runnerState.isRunning
                ? null
                : (v) => setState(() => _stopOnError = v),
          ),

          const SizedBox(height: 12),

          // Control buttons: Start / Stop / Reset.
          Row(
            children: [
              // Start button.
              if (!runnerState.isRunning) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _startRun,
                    icon: const Icon(Symbols.play_arrow, size: 18),
                    label: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Stop button (while running).
              if (runnerState.isRunning) ...[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _stopRun,
                    icon: const Icon(Symbols.stop, size: 18),
                    label: const Text('Stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Reset button (when not running).
              if (!runnerState.isRunning && runnerState.isComplete) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetRun,
                    icon: const Icon(Symbols.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress bar
  // ---------------------------------------------------------------------------

  /// Builds a linear progress indicator showing current request index / total.
  Widget _buildProgressBar(ColorScheme colorScheme, RunnerState runnerState) {
    final progress = runnerState.progress;
    final label =
        '${runnerState.currentRequestIndex} / ${runnerState.totalRequests}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Progress',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: runnerState.isRunning ? progress : 1.0,
          minHeight: 4,
          borderRadius: BorderRadius.zero,
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Results list
  // ---------------------------------------------------------------------------

  /// Empty placeholder shown before any run has been started.
  Widget _buildEmptyResults(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.run_circle,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Ready to run',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Start" to execute all requests in this collection.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a card for a single request result.
  Widget _buildResultCard(
    RequestRunnerResult result,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final passed = result.allAssertionsPassed && result.error == null;
    final hasError = result.error != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showResultDetail(result),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: pass/fail icon, name, method chip, status badge.
              Row(
                children: [
                  // Pass / fail icon.
                  Icon(
                    hasError
                        ? Symbols.error
                        : passed
                            ? Symbols.check_circle
                            : Symbols.cancel,
                    size: 20,
                    color: hasError
                        ? colorScheme.error
                        : passed
                            ? Colors.green
                            : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  // Request name.
                  Expanded(
                    child: Text(
                      result.requestName,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Method chip.
                  MethodChipFromString(method: result.method),
                  const SizedBox(width: 8),
                  // Status code badge.
                  StatusCodeBadge(statusCode: result.statusCode),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: URL (truncated), response time, assertion summary.
              Row(
                children: [
                  Icon(
                    Symbols.link,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      result.url.truncate(60),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Response time.
                  Icon(
                    Symbols.speed,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${result.responseTimeMs}ms',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Assertion summary.
                  if (result.assertions.isNotEmpty) ...[
                    Icon(
                      passed ? Symbols.verified : Symbols.warning,
                      size: 14,
                      color: passed ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${result.assertions.where((a) => a.passed == true).length}/${result.assertions.length}',
                      style: textTheme.bodySmall?.copyWith(
                        color: passed ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),

              // Error message (if any).
              if (hasError) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.error!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Summary bar
  // ---------------------------------------------------------------------------

  /// Builds the summary bar at the bottom of the screen after a run completes.
  Widget _buildSummaryBar(
    ColorScheme colorScheme,
    TextTheme textTheme,
    RunnerState runnerState,
  ) {
    final result = runnerState.finalResult!;

    // Format the total duration in a human-readable way.
    final durationText = _formatDuration(result.durationMs);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Status icon.
          Icon(
            result.status == RunnerStatus.completed &&
                    result.failedCount == 0
                ? Symbols.check_circle
                : result.status == RunnerStatus.cancelled
                    ? Symbols.cancel
                    : Symbols.error,
            color: result.status == RunnerStatus.completed &&
                    result.failedCount == 0
                ? Colors.green
                : result.status == RunnerStatus.cancelled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),

          // Passed count.
          Text(
            '${result.passedCount} passed',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),

          // Failed count.
          Text(
            '${result.failedCount} failed',
            style: textTheme.bodyMedium?.copyWith(
              color: result.failedCount > 0 ? colorScheme.error : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),

          // Total time.
          Text(
            durationText,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Result detail bottom sheet
  // ---------------------------------------------------------------------------

  /// Shows a modal bottom sheet with full details for a single request result.
  void _showResultDetail(RequestRunnerResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Drag handle.
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title row.
              Row(
                children: [
                  MethodChipFromString(method: result.method),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.requestName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusCodeBadge(statusCode: result.statusCode),
                ],
              ),
              const SizedBox(height: 16),

              // URL.
              _DetailSection(
                title: 'URL',
                icon: Symbols.link,
                child: SelectableText(
                  result.url,
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),

              // Response time.
              _DetailSection(
                title: 'Response Time',
                icon: Symbols.speed,
                child: Text(
                  '${result.responseTimeMs} ms',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: result.responseTimeMs > 3000
                        ? colorScheme.error
                        : result.responseTimeMs > 1000
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Assertions section (if any).
              if (result.assertions.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Assertions',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.assertions.map(
                  (a) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: a.passed == true
                        ? colorScheme.primaryContainer.withOpacity(0.3)
                        : colorScheme.errorContainer.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(
                            a.passed == true
                                ? Symbols.check_circle
                                : Symbols.cancel,
                            size: 18,
                            color: a.passed == true
                                ? Colors.green
                                : colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${a.type.name} ${a.operator.name} "${a.expectedValue}"',
                                  style: textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (a.actualValue != null)
                                  Text(
                                    'Actual: ${a.actualValue}',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (a.errorMessage != null)
                                  Text(
                                    a.errorMessage!,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.error,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // Response body.
              if (result.responseBody.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Response Body',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    result.responseBody.truncate(3000),
                    style: textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              // Error.
              if (result.error != null) ...[
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Error',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    result.error!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Formats a duration in milliseconds to a human-readable string.
  ///
  /// Examples: "1.2s", "345ms", "0ms".
  static String _formatDuration(int ms) {
    if (ms >= 1000) {
      return '${(ms / 1000).toStringAsFixed(1)}s';
    }
    return '${ms}ms';
  }
}

// =============================================================================
// Detail Section widget (used in bottom sheet)
// =============================================================================

/// A compact labeled section used in the result detail bottom sheet.
class _DetailSection extends StatelessWidget {
  /// Section title.
  final String title;

  /// Material Symbols icon.
  final IconData icon;

  /// Content widget displayed below the title.
  final Widget child;

  /// Creates a [_DetailSection].
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}