/// Barrel file that re-exports all domain entities.
///
/// Import this single file to gain access to every entity in the domain layer.
library;

// Core entities.
export 'workspace.dart';
export 'api_request.dart';
export 'api_response.dart';
export 'collection.dart';
export 'environment.dart';
export 'environment_variable.dart';

// Supporting value objects.
export 'key_value_item.dart';
export 'form_data_item.dart';
export 'proxy_settings.dart';
export 'app_settings.dart';

// History and testing entities.
export 'request_history.dart';
export 'assertion.dart';
export 'request_runner_result.dart';
export 'runner_result.dart';