import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'environment.dart';

/// Global application configuration accessible via Riverpod.
///
/// Set once at startup via the appropriate entry point
/// (main_dev.dart, main_staging.dart, main_prod.dart).
class AppConfig {
  const AppConfig({required this.environment});

  final EnvironmentConfig environment;
}

/// Provider that holds the current [AppConfig].
///
/// This is overridden at app startup in the ProviderScope.
final appConfigProvider = Provider<AppConfig>((ref) {
  // Default to development — overridden in main entry points.
  return const AppConfig(environment: EnvironmentConfig.development);
});
