import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:api_tester/domain/entities/api_request.dart';
import 'package:api_tester/domain/entities/api_response.dart';
import 'package:api_tester/domain/entities/assertion.dart';
import 'package:api_tester/domain/entities/collection.dart';
import 'package:api_tester/domain/entities/runner_result.dart';
import 'package:api_tester/domain/repositories/environment_repository.dart';
import 'package:api_tester/domain/repositories/request_repository.dart';
import 'package:api_tester/domain/usecases/collection/run_collection.dart';

class MockRequestRepository extends Mock implements RequestRepository {}

class MockEnvironmentRepository extends Mock implements EnvironmentRepository {}

void main() {
  late MockRequestRepository mockRequestRepo;
  late MockEnvironmentRepository mockEnvRepo;
  late RunCollection runCollection;

  final now = DateTime.now();

  ApiRequest _makeRequest({
    required String id,
    String name = 'Test Request',
    HttpMethod method = HttpMethod.get,
    String url = 'https://api.example.com/test',
    List<KeyValueItem> headers = const [],
    BodyType bodyType = BodyType.none,
    String bodyContent = '',
  }) {
    return ApiRequest(
      id: id,
      workspaceId: 'ws-1',
      name: name,
      method: method,
      url: url,
      headers: headers,
      bodyType: bodyType,
      bodyContent: bodyContent,
      createdAt: now,
      updatedAt: now,
    );
  }

  setUp(() {
    mockRequestRepo = MockRequestRepository();
    mockEnvRepo = MockEnvironmentRepository();

    // Default: resolveVariables returns input as-is.
    registerFallbackValue('ws-1');
    registerFallbackValue('any-input');
    when(() => mockEnvRepo.resolveVariables(any(), any()))
        .thenAnswer((invocation) async => invocation.positionalArguments[1] as String);
  });

  tearDown(() {
    reset(mockRequestRepo);
    reset(mockEnvRepo);
  });

  group('RunCollection', () {
    group('running collection with 2 requests', () {
      test('executes all requests and returns completed status when all pass',
          () async {
        final req1 = _makeRequest(id: 'r1', name: 'First');
        final req2 = _makeRequest(id: 'r2', name: 'Second');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Test Collection',
          requestIds: ['r1', 'r2'],
          createdAt: now,
          updatedAt: now,
        );

        when(() => mockRequestRepo.sendRequest(any(that: isA<ApiRequest>())))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '{"ok": true}',
                  responseTimeMs: 50,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1, 'r2': req2},
          assertions: {},
        ));

        expect(result.results, hasLength(2));
        expect(result.passedCount, equals(2));
        expect(result.failedCount, equals(0));
        expect(result.status, equals(RunnerStatus.completed));
        verify(() => mockRequestRepo.sendRequest(any())).called(2);
      });
    });

    group('stop on error', () {
      test('stops executing after first failure when stopOnError is true',
          () async {
        final req1 = _makeRequest(id: 'r1', name: 'Failing');
        final req2 = _makeRequest(id: 'r2', name: 'Should not run');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Stop on Error',
          requestIds: ['r1', 'r2'],
          stopOnError: true,
          createdAt: now,
          updatedAt: now,
        );

        // First request returns 500 (failure with no assertions means pass
        // is based on allAssertionsPassed which defaults to true).
        // To make it fail, we attach a failing assertion.
        final failingAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.statusCode,
          expectedValue: '200',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 500,
                  body: 'Internal Server Error',
                  responseTimeMs: 100,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1, 'r2': req2},
          assertions: {
            'r1': [failingAssertion],
          },
        ));

        // First request fails (500 != 200), so second should not run.
        expect(result.results, hasLength(1));
        expect(result.failedCount, equals(1));
        expect(result.status, equals(RunnerStatus.failed));
        // Only the first request should have been sent.
        verify(() => mockRequestRepo.sendRequest(any())).called(1);
      });

      test('continues on error when stopOnError is false', () async {
        final req1 = _makeRequest(id: 'r1', name: 'Failing');
        final req2 = _makeRequest(id: 'r2', name: 'Passing');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Continue on Error',
          requestIds: ['r1', 'r2'],
          stopOnError: false,
          createdAt: now,
          updatedAt: now,
        );

        final failingAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.statusCode,
          expectedValue: '200',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 500,
                  body: 'Error',
                  responseTimeMs: 50,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1, 'r2': req2},
          assertions: {
            'r1': [failingAssertion],
          },
        ));

        // Both requests should run.
        expect(result.results, hasLength(2));
        verify(() => mockRequestRepo.sendRequest(any())).called(2);
      });
    });

    group('delay between requests', () {
      test('applies delay between requests when configured', () async {
        final req1 = _makeRequest(id: 'r1', name: 'First');
        final req2 = _makeRequest(id: 'r2', name: 'Second');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Delayed',
          requestIds: ['r1', 'r2'],
          delayBetweenRequestsMs: 100,
          createdAt: now,
          updatedAt: now,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '{}',
                  responseTimeMs: 10,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final stopwatch = Stopwatch()..start();
        await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1, 'r2': req2},
          assertions: {},
        ));
        stopwatch.stop();

        // With 100ms delay, total should be at least 100ms.
        expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(80));
      });
    });

    group('assertion evaluation', () {
      test('assertion passes when status code matches', () async {
        final req1 = _makeRequest(id: 'r1', name: 'Status Check');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Assert Pass',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        final passingAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.statusCode,
          expectedValue: '200',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '{"ok": true}',
                  responseTimeMs: 50,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {'r1': [passingAssertion]},
        ));

        expect(result.results.first.allAssertionsPassed, isTrue);
        expect(result.passedCount, equals(1));
        expect(result.failedCount, equals(0));
      });

      test('assertion fails when status code does not match', () async {
        final req1 = _makeRequest(id: 'r1', name: 'Status Check');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Assert Fail',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        final failingAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.statusCode,
          expectedValue: '201',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: 'OK',
                  responseTimeMs: 50,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {'r1': [failingAssertion]},
        ));

        expect(result.results.first.allAssertionsPassed, isFalse);
        expect(result.failedCount, equals(1));
      });

      test('bodyContains assertion passes when body contains expected text',
          () async {
        final req1 = _makeRequest(id: 'r1', name: 'Body Check');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Body Contains',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        final bodyAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.bodyContains,
          expectedValue: 'success',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '{"result": "success"}',
                  responseTimeMs: 50,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {'r1': [bodyAssertion]},
        ));

        expect(result.results.first.allAssertionsPassed, isTrue);
      });

      test('bodyContains assertion fails when body does not contain text',
          () async {
        final req1 = _makeRequest(id: 'r1', name: 'Body Check');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Body Not Contains',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        final bodyAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.bodyContains,
          expectedValue: 'error',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '{"result": "success"}',
                  responseTimeMs: 50,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {'r1': [bodyAssertion]},
        ));

        expect(result.results.first.allAssertionsPassed, isFalse);
        expect(result.results.first.assertions.first.errorMessage,
            contains('does not contain'));
      });

      test('headerExists assertion passes when header is present', () async {
        final req1 = _makeRequest(id: 'r1', name: 'Header Check');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Header Exists',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        final headerAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.headerExists,
          expectedValue: 'Content-Type',
          operator: AssertionOperator.equals,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '',
                  responseTimeMs: 50,
                  headers: {'content-type': 'application/json'},
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {'r1': [headerAssertion]},
        ));

        expect(result.results.first.allAssertionsPassed, isTrue);
      });

      test('responseTime assertion passes when time is less than expected',
          () async {
        final req1 = _makeRequest(id: 'r1', name: 'Time Check');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Response Time',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        final timeAssertion = Assertion(
          id: 'a1',
          requestId: 'r1',
          type: AssertionType.responseTime,
          expectedValue: '500',
          operator: AssertionOperator.lessThan,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenAnswer((_) async => ApiResponse(
                  statusCode: 200,
                  body: '{}',
                  responseTimeMs: 100,
                ));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {'r1': [timeAssertion]},
        ));

        expect(result.results.first.allAssertionsPassed, isTrue);
      });

      test('handles network error gracefully', () async {
        final req1 = _makeRequest(id: 'r1', name: 'Network Error');

        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Error Test',
          requestIds: ['r1'],
          createdAt: now,
          updatedAt: now,
        );

        when(() => mockRequestRepo.sendRequest(any()))
            .thenThrow(Exception('Network unreachable'));

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {'r1': req1},
          assertions: {},
        ));

        expect(result.results.first.allAssertionsPassed, isFalse);
        expect(result.results.first.error, isNotNull);
        expect(result.failedCount, equals(1));
      });

      test('handles missing request in collection', () async {
        final collection = Collection(
          id: 'col-1',
          workspaceId: 'ws-1',
          name: 'Missing Request',
          requestIds: ['nonexistent-id'],
          createdAt: now,
          updatedAt: now,
        );

        runCollection = RunCollection(mockRequestRepo, mockEnvRepo);

        final result = await runCollection(RunCollectionParams(
          collection: collection,
          requests: {},
          assertions: {},
        ));

        expect(result.results, hasLength(1));
        expect(result.results.first.error, contains('not found'));
        expect(result.failedCount, equals(1));
      });
    });
  });
}