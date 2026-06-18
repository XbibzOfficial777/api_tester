/// @file run_collection.dart
/// @brief Use case for executing all requests in a collection sequentially.
///
/// Runs each request in the collection one at a time, evaluates assertions,
/// and aggregates the results into a [RunnerResult]. Supports configurable
/// delays between requests and optional stop-on-error behavior.
library;

import '../../entities/api_request.dart';
import '../../entities/api_response.dart';
import '../../entities/assertion.dart';
import '../../entities/collection.dart';
import '../../entities/request_runner_result.dart';
import '../../entities/runner_result.dart';
import '../../repositories/environment_repository.dart';
import '../../repositories/request_repository.dart';
import '../usecase.dart';

/// Parameters required to run a collection.
class RunCollectionParams {
  /// The collection to execute (provides request order, delay, stopOnError).
  final Collection collection;

  /// All requests that belong to this collection, keyed by ID for O(1) lookup.
  /// The collection's [requestIds] determines the execution order.
  final Map<String, ApiRequest> requests;

  /// Assertions keyed by request ID. Requests without assertions have empty lists.
  final Map<String, List<Assertion>> assertions;

  /// Creates parameter object for collection execution.
  ///
  /// [collection] - The collection entity defining execution order and settings.
  /// [requests] - Map of request ID to request entity for all requests in the collection.
  /// [assertions] - Map of request ID to assertions for each request.
  const RunCollectionParams({
    required this.collection,
    required this.requests,
    required this.assertions,
  });
}

/// Executes all requests in a collection sequentially.
///
/// For each request:
/// 1. Resolves environment variables in URL, headers, and body.
/// 2. Sends the HTTP request via the repository.
/// 3. Evaluates all assertions attached to the request.
/// 4. Records the result.
///
/// If [Collection.stopOnError] is true and a request fails (network error
/// or any assertion fails), the run is aborted and remaining requests
/// are not executed. The [RunnerResult.status] is set to [RunnerStatus.failed].
class RunCollection extends UseCase<RunnerResult, RunCollectionParams> {
  /// Repository for executing HTTP requests.
  final RequestRepository _requestRepository;

  /// Repository for resolving environment variables.
  final EnvironmentRepository _environmentRepository;

  /// Creates a new [RunCollection] use case.
  RunCollection(this._requestRepository, this._environmentRepository);

  /// Executes all requests in the collection and returns aggregate results.
  @override
  Future<RunnerResult> call(RunCollectionParams params) async {
    final collection = params.collection;
    final startedAt = DateTime.now();

    // Initialize the runner result in "running" state.
    final runnerResult = RunnerResult(
      id: '', // Assigned by caller or repository.
      collectionId: collection.id,
      totalRequests: collection.requestIds.length,
      startedAt: startedAt,
    );

    final results = <RequestRunnerResult>[];
    var passedCount = 0;
    var failedCount = 0;

    for (var i = 0; i < collection.requestIds.length; i++) {
      final requestId = collection.requestIds[i];
      final request = params.requests[requestId];

      // Skip if the request data is not available.
      if (request == null) {
        final errorResult = RequestRunnerResult(
          requestId: requestId,
          requestName: 'Unknown Request',
          method: 'UNKNOWN',
          url: '',
          error: 'Request with ID $requestId not found',
          timestamp: DateTime.now(),
        );
        results.add(errorResult);
        failedCount++;
        if (collection.stopOnError) break;
        continue;
      }

      // Add configured delay between requests (skip delay before the first request).
      if (i > 0 && collection.delayBetweenRequestsMs > 0) {
        await Future.delayed(
          Duration(milliseconds: collection.delayBetweenRequestsMs),
        );
      }

      // Resolve environment variables in the request.
      final resolvedUrl = await _environmentRepository.resolveVariables(
        request.workspaceId,
        request.url,
      );

      final resolvedHeaders = await Future.wait(
        request.headers.where((h) => h.isEnabled).map((h) async {
          final rk = await _environmentRepository.resolveVariables(
            request.workspaceId,
            h.key,
          );
          final rv = await _environmentRepository.resolveVariables(
            request.workspaceId,
            h.value,
          );
          return h.copyWith(key: rk, value: rv);
        }),
      );

      String resolvedBody = request.bodyContent;
      if (request.bodyType == BodyType.raw) {
        resolvedBody = await _environmentRepository.resolveVariables(
          request.workspaceId,
          request.bodyContent,
        );
      }

      final resolvedRequest = request.copyWith(
        url: resolvedUrl,
        headers: resolvedHeaders,
        bodyContent: resolvedBody,
      );

      // Send the request and evaluate assertions.
      RequestRunnerResult result;
      try {
        final response = await _requestRepository.sendRequest(resolvedRequest);
        final evaluatedAssertions = _evaluateAssertions(
          params.assertions[requestId] ?? [],
          response,
        );
        final allPassed = evaluatedAssertions.every((a) => a.passed == true);

        // Truncate the response body for the runner result display.
        String truncatedBody = response.body;
        if (truncatedBody.length > 500) {
          truncatedBody = '${truncatedBody.substring(0, 500)}...';
        }

        result = RequestRunnerResult(
          requestId: requestId,
          requestName: request.name,
          method: request.method.name.toUpperCase(),
          url: resolvedUrl,
          statusCode: response.statusCode,
          responseTimeMs: response.responseTimeMs,
          responseBody: truncatedBody,
          assertions: evaluatedAssertions,
          allAssertionsPassed: allPassed,
          timestamp: DateTime.now(),
        );

        if (allPassed) {
          passedCount++;
        } else {
          failedCount++;
        }
      } catch (e) {
        result = RequestRunnerResult(
          requestId: requestId,
          requestName: request.name,
          method: request.method.name.toUpperCase(),
          url: resolvedUrl,
          error: e.toString(),
          assertions: [],
          allAssertionsPassed: false,
          timestamp: DateTime.now(),
        );
        failedCount++;
      }

      results.add(result);

      // Stop on error if configured and the request failed.
      if (collection.stopOnError && !result.allAssertionsPassed) {
        break;
      }
    }

    final completedAt = DateTime.now();
    final durationMs = completedAt.difference(startedAt).inMilliseconds;

    // Determine overall status: if all executed requests passed, completed; otherwise failed.
    final allExecutedPassed = results.every((r) => r.allAssertionsPassed);
    final status = allExecutedPassed ? RunnerStatus.completed : RunnerStatus.failed;

    return runnerResult.copyWith(
      results: results,
      passedCount: passedCount,
      failedCount: failedCount,
      completedAt: completedAt,
      durationMs: durationMs,
      status: status,
    );
  }

  /// Evaluates a list of assertions against a response.
  ///
  /// For each assertion, extracts the relevant value from the response,
  /// applies the comparison operator, and sets [passed] and [errorMessage].
  List<Assertion> _evaluateAssertions(
    List<Assertion> assertions,
    ApiResponse response,
  ) {
    return assertions.map((assertion) {
      String? actualValue;
      bool passed = false;
      String? errorMessage;

      switch (assertion.type) {
        case AssertionType.statusCode:
          actualValue = response.statusCode.toString();
          passed = _compare(
            actualValue,
            assertion.expectedValue,
            assertion.operator,
          );
          break;

        case AssertionType.bodyContains:
          actualValue = response.body;
          // For bodyContains, we always use "contains" semantics regardless of operator.
          passed = response.body.contains(assertion.expectedValue);
          if (!passed) {
            errorMessage =
                'Body does not contain "${assertion.expectedValue}"';
          }
          break;

        case AssertionType.headerExists:
          final headerKey = assertion.expectedValue.toLowerCase();
          actualValue =
              response.responseHeaders[headerKey] ?? 'NOT_FOUND';
          passed = response.responseHeaders.containsKey(headerKey);
          if (!passed) {
            errorMessage =
                'Header "${assertion.expectedValue}" not found in response';
          }
          break;

        case AssertionType.responseTime:
          actualValue = response.responseTimeMs.toString();
          passed = _compare(
            actualValue,
            assertion.expectedValue,
            assertion.operator,
          );
          break;
      }

      if (assertion.type != AssertionType.bodyContains &&
          assertion.type != AssertionType.headerExists &&
          !passed) {
        errorMessage =
            'Expected ${assertion.operator.name} "${assertion.expectedValue}" but got "$actualValue"';
      }

      return assertion.copyWith(
        actualValue: actualValue,
        passed: passed,
        errorMessage: errorMessage,
      );
    }).toList();
  }

  /// Compares an actual value against an expected value using the given operator.
  ///
  /// Returns true if the comparison succeeds.
  bool _compare(
    String actual,
    String expected,
    AssertionOperator operator,
  ) {
    switch (operator) {
      case AssertionOperator.equals:
        return actual == expected;

      case AssertionOperator.notEquals:
        return actual != expected;

      case AssertionOperator.contains:
        return actual.contains(expected);

      case AssertionOperator.lessThan:
        final actualNum = int.tryParse(actual) ?? 0;
        final expectedNum = int.tryParse(expected) ?? 0;
        return actualNum < expectedNum;

      case AssertionOperator.greaterThan:
        final actualNum = int.tryParse(actual) ?? 0;
        final expectedNum = int.tryParse(expected) ?? 0;
        return actualNum > expectedNum;

      case AssertionOperator.matches:
        try {
          final regex = RegExp(expected);
          return regex.hasMatch(actual);
        } catch (_) {
          return false;
        }
    }
  }
}