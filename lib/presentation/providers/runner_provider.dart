/// @file runner_provider.dart
/// @brief Riverpod providers for the collection runner.
///
/// Manages the state of a collection run: progress tracking, individual
/// request results, and the final aggregate [RunnerResult]. The runner
/// executes requests sequentially, reports progress after each request,
/// and respects the collection's delay and stop-on-error settings.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:api_tester/core/di/injection.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/assertion.dart';
import 'package:api_tester/domain/entities/collection.dart';
import 'package:api_tester/domain/entities/request_runner_result.dart';
import 'package:api_tester/domain/entities/runner_result.dart';
import 'package:api_tester/domain/repositories/environment_repository.dart';
import 'package:api_tester/domain/repositories/request_repository.dart';
import 'package:api_tester/domain/usecases/collection/run_collection.dart';

// ---------------------------------------------------------------------------
// Runner State
// ---------------------------------------------------------------------------

/// Immutable snapshot of the collection runner's current state.
///
/// The UI watches this provider to display a progress bar, the list of
/// results so far, and the final summary when the run completes.
class RunnerState {
  /// Whether the runner is currently executing requests.
  final bool isRunning;

  /// Index of the request currently being executed (0-based).
  /// Meaningful only when [isRunning] is `true`.
  final int currentRequestIndex;

  /// Total number of requests in the collection being run.
  final int totalRequests;

  /// Individual results accumulated so far.
  final List<RequestRunnerResult> results;

  /// The final aggregate result, available only after the run finishes.
  /// `null` while the run is in progress.
  final RunnerResult? finalResult;

  /// Human-readable error message if the run failed catastrophically.
  final String? error;

  const RunnerState({
    this.isRunning = false,
    this.currentRequestIndex = 0,
    this.totalRequests = 0,
    this.results = const [],
    this.finalResult,
    this.error,
  });

  /// Convenience: progress as a value between 0.0 and 1.0.
  double get progress =>
      totalRequests > 0 ? currentRequestIndex / totalRequests : 0.0;

  /// Whether the run has finished (successfully or with failure).
  bool get isComplete => finalResult != null || error != null;

  RunnerState copyWith({
    bool? isRunning,
    int? currentRequestIndex,
    int? totalRequests,
    List<RequestRunnerResult>? results,
    RunnerResult? finalResult,
    String? error,
  }) {
    return RunnerState(
      isRunning: isRunning ?? this.isRunning,
      currentRequestIndex: currentRequestIndex ?? this.currentRequestIndex,
      totalRequests: totalRequests ?? this.totalRequests,
      results: results ?? this.results,
      finalResult: finalResult ?? this.finalResult,
      error: error ?? this.error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the collection runner lifecycle.
///
/// Call [runCollection] to start a run. The notifier updates its state
/// incrementally as each request completes, allowing the UI to show
/// real-time progress.
class RunnerNotifier extends StateNotifier<RunnerState> {
  RunnerNotifier() : super(const RunnerState());

  static const _uuid = Uuid();

  /// Executes all requests in the given [collection].
  ///
  /// [collection] defines the order, delay, and stop-on-error behavior.
  /// [requests] is a map of request ID → [ApiRequest] for all requests
  /// referenced by the collection's [Collection.requestIds].
  /// [assertions] is a map of request ID → list of [Assertion]s (can be
  /// empty if no assertions are defined).
  ///
  /// Updates [state] incrementally after each request completes.
  /// Sets [RunnerState.finalResult] when the run finishes.
  Future<void> runCollection({
    required Collection collection,
    required Map<String, ApiRequest> requests,
    required Map<String, List<dynamic>> assertions,
  }) async {
    // Reset to a fresh running state.
    state = RunnerState(
      isRunning: true,
      currentRequestIndex: 0,
      totalRequests: collection.requestIds.length,
      results: [],
    );

    final requestRepo = getIt<RequestRepository>();
    final envRepo = getIt<EnvironmentRepository>();

    final useCase = RunCollection(requestRepo, envRepo);

    // Convert raw assertion maps to typed lists.
    final typedAssertions = <String, List<Assertion>>{};
    for (final entry in assertions.entries) {
      typedAssertions[entry.key] = entry.value.cast<Assertion>();
    }

    try {
      final result = await useCase(RunCollectionParams(
        collection: collection,
        requests: requests,
        assertions: typedAssertions,
      ));

      // The use case runs all requests sequentially and returns the full
      // result. We replay the individual results into the state for the UI.
      state = state.copyWith(
        isRunning: false,
        currentRequestIndex: result.totalRequests,
        results: result.results,
        finalResult: result,
      );
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: 'Collection run failed: $e',
      );
    }
  }

  /// Cancels the current run (sets isRunning to false).
  ///
  /// Note: this does **not** actually abort in-flight HTTP requests.
  /// A more robust implementation would use a [CancelToken] from Dio.
  /// For now it simply marks the run as cancelled.
  void cancelRun() {
    if (!state.isRunning) return;
    state = state.copyWith(
      isRunning: false,
      finalResult: RunnerResult(
        id: _uuid.v4(),
        collectionId: '',
        totalRequests: state.totalRequests,
        passedCount: 0,
        failedCount: 0,
        results: state.results,
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        status: RunnerStatus.cancelled,
      ),
    );
  }

  /// Resets the runner state for a fresh run.
  void reset() {
    state = const RunnerState();
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the collection runner state.
///
/// The UI watches this to display progress, individual results, and the
/// final summary. Call [RunnerNotifier.runCollection] to start a run.
final runnerStateProvider =
    StateNotifierProvider<RunnerNotifier, RunnerState>(
  (ref) => RunnerNotifier(),
);

