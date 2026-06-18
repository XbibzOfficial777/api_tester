/// @file injection.dart
/// @brief Dependency injection setup using GetIt with Riverpod integration.
///
/// Configures the service locator with all core singletons (Dio, database)
/// and provides a Riverpod [Provider] that exposes the GetIt instance so
/// that widgets and use-case call-sites can request dependencies from
/// either DI system transparently.
///
/// Usage (in main.dart):
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await configureDependencies();
///   runApp(const ProviderScope(child: MyApp()));
/// }
/// ```

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../utils/dio_interceptor.dart';

/// Global service locator instance.
///
/// All registrations happen through this single [GetIt] instance. Prefer
/// accessing it via [serviceLocatorProvider] inside Riverpod widgets so that
/// the dependency graph is explicit and testable.
final getIt = GetIt.instance;

/// Riverpod [Provider] that exposes the [GetIt] service locator.
///
/// Widgets and Riverpod-based classes should depend on this provider rather
/// than calling [GetIt.instance] directly. This keeps the dependency graph
/// auditable and enables easy swapping in tests.
///
/// ```dart
/// final dio = ref.read(serviceLocatorProvider).get<Dio>();
/// ```
final Provider<GetIt> serviceLocatorProvider = Provider<GetIt>((ref) {
  return getIt;
});

/// Configures all application dependencies in the correct order.
///
/// **Registration order matters** — services with no dependencies are
/// registered first, followed by services that depend on them.
///
/// Call this exactly once from `main()` before `runApp()`:
/// ```dart
/// await configureDependencies();
/// ```
///
/// The function is `async` because the Drift database initialisation is
/// an asynchronous operation. If the database layer is not yet available
/// the call will still succeed — the DB registration will be skipped.
Future<void> configureDependencies() async {
  // -----------------------------------------------------------------------
  // 1. External Clients — no intra-app dependencies
  // -----------------------------------------------------------------------
  _registerDio();

  // -----------------------------------------------------------------------
  // 2. Local Database — singleton, async init
  // -----------------------------------------------------------------------
  // The AppDatabase registration is intentionally deferred to the data layer
  // bootstrap to keep the core layer free of generated Drift code.
  // In `main()` the data layer calls:
  //   getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
  // -----------------------------------------------------------------------

  // -----------------------------------------------------------------------
  // 3. Repositories — lazy singletons, depend on Dio / DB
  // -----------------------------------------------------------------------
  // Repositories are registered by the data layer bootstrap:
  //   getIt.registerLazySingleton<RequestRepository>(
  //     () => RequestRepositoryImpl(getIt<Dio>(), getIt<AppDatabase>()),
  //   );
  //   getIt.registerLazySingleton<HistoryRepository>(
  //     () => HistoryRepositoryImpl(getIt<AppDatabase>()),
  //   );
  //   getIt.registerLazySingleton<CollectionRepository>(
  //     () => CollectionRepositoryImpl(getIt<AppDatabase>()),
  //   );
  //   getIt.registerLazySingleton<EnvironmentRepository>(
  //     () => EnvironmentRepositoryImpl(getIt<AppDatabase>()),
  //   );
  //   getIt.registerLazySingleton<SettingsRepository>(
  //     () => SettingsRepositoryImpl(getIt<AppDatabase>()),
  //   );
  // -----------------------------------------------------------------------

  // -----------------------------------------------------------------------
  // 4. Use Cases — factories (new instance per request)
  // -----------------------------------------------------------------------
  // Use cases are registered by the domain layer bootstrap:
  //   getIt.registerFactory<SendRequestUseCase>(
  //     () => SendRequestUseCase(getIt<RequestRepository>()),
  //   );
  //   getIt.registerFactory<GetHistoryUseCase>(
  //     () => GetHistoryUseCase(getIt<HistoryRepository>()),
  //   );
  //   getIt.registerFactory<SaveHistoryUseCase>(
  //     () => SaveHistoryUseCase(getIt<HistoryRepository>()),
  //   );
  //   getIt.registerFactory<DeleteHistoryUseCase>(
  //     () => DeleteHistoryUseCase(getIt<HistoryRepository>()),
  //   );
  //   getIt.registerFactory<ManageCollectionsUseCase>(
  //     () => ManageCollectionsUseCase(getIt<CollectionRepository>()),
  //   );
  //   getIt.registerFactory<ManageEnvironmentsUseCase>(
  //     () => ManageEnvironmentsUseCase(getIt<EnvironmentRepository>()),
  //   );
  //   getIt.registerFactory<GetSettingsUseCase>(
  //     () => GetSettingsUseCase(getIt<SettingsRepository>()),
  //   );
  //   getIt.registerFactory<UpdateSettingsUseCase>(
  //     () => UpdateSettingsUseCase(getIt<SettingsRepository>()),
  //   );
  // -----------------------------------------------------------------------
}

/// Registers a pre-configured [Dio] HTTP client as a lazy singleton.
///
/// The instance ships with:
/// - A sensible [BaseOptions] timeout and default headers.
/// - [LoggingInterceptor] for development-time request/response logging.
/// - [RetryInterceptor] for automatic retries on transient failures.
/// - [AuthInterceptor] for environment-variable-driven Bearer tokens.
///
/// To retrieve elsewhere:
/// ```dart
/// final dio = getIt<Dio>();
/// ```
void _registerDio() {
  getIt.registerLazySingleton<Dio>(() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: AppConstants.defaultTimeout,
        receiveTimeout: AppConstants.defaultTimeout,
        sendTimeout: AppConstants.defaultTimeout,
        maxRedirects: AppConstants.maxRedirects,
        headers: Map<String, dynamic>.from(AppConstants.defaultHeaders),
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    // ---- Interceptors (order matters: first added = outermost) --------
    dio.interceptors.addAll([
      AuthInterceptor(),
      RetryInterceptor(
        retryCount: ApiConstants.maxRetryCount,
        retryDelays: _buildRetryDelays(ApiConstants.maxRetryCount),
      ),
      LoggingInterceptor(),
    ]);

    return dio;
  });
}

/// Builds a list of retry delays using exponential back-off.
///
/// For [count] = 3 and base = 1000 ms this produces [1000, 2000, 4000].
/// Each delay is capped at [ApiConstants.retryMaxDelayMs].
List<int> _buildRetryDelays(int count) {
  final delays = <int>[];
  for (var i = 0; i < count; i++) {
    final delay = ApiConstants.retryBaseDelayMs * (1 << i); // 2^i
    delays.add(delay.clamp(0, ApiConstants.retryMaxDelayMs));
  }
  return delays;
}
