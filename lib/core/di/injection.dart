/// @file injection.dart
/// @brief Dependency injection setup using GetIt with Riverpod integration.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../utils/dio_interceptor.dart';
import '../../data/datasources/local/database/app_database.dart';
import '../../data/repositories/request_repository_impl.dart';
import '../../data/repositories/history_repository_impl.dart';
import '../../data/repositories/collection_repository_impl.dart';
import '../../data/repositories/environment_repository_impl.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../data/repositories/workspace_repository_impl.dart';
import '../../domain/repositories/repositories.dart';

/// Global service locator instance.
final getIt = GetIt.instance;

/// Riverpod [Provider] that exposes the [GetIt] service locator.
final Provider<GetIt> serviceLocatorProvider = Provider<GetIt>((ref) {
  return getIt;
});

/// Configures all application dependencies in the correct order.
Future<void> configureDependencies() async {
  // 1. External Clients
  _registerDio();

  // 2. Local Database (LazyDatabase handles path internally)
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // 3. Repositories
  getIt.registerLazySingleton<WorkspaceRepository>(
    () => WorkspaceRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<RequestRepository>(
    () => RequestRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<HistoryRepository>(
    () => HistoryRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<CollectionRepository>(
    () => CollectionRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<EnvironmentRepository>(
    () => EnvironmentRepositoryImpl(getIt<AppDatabase>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt<AppDatabase>()),
  );
}

/// Registers a pre-configured [Dio] HTTP client as a lazy singleton.
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
List<int> _buildRetryDelays(int count) {
  final delays = <int>[];
  for (var i = 0; i < count; i++) {
    final delay = ApiConstants.retryBaseDelayMs * (1 << i);
    delays.add(delay.clamp(0, ApiConstants.retryMaxDelayMs));
  }
  return delays;
}