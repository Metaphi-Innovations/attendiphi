/// Application environment configuration.
///
/// Each environment uses a different Firebase project and log level.
enum Environment {
  development,
  staging,
  production,
}

/// Holds the current environment configuration.
class EnvironmentConfig {
  const EnvironmentConfig._({
    required this.environment,
    required this.enableCrashlytics,
    required this.enableAppCheck,
    required this.appCheckDebugMode,
  });

  /// Development configuration.
  static const development = EnvironmentConfig._(
    environment: Environment.development,
    enableCrashlytics: false,
    enableAppCheck: false,
    appCheckDebugMode: true,
  );

  /// Staging configuration.
  static const staging = EnvironmentConfig._(
    environment: Environment.staging,
    enableCrashlytics: true,
    enableAppCheck: true,
    appCheckDebugMode: true,
  );

  /// Production configuration.
  static const production = EnvironmentConfig._(
    environment: Environment.production,
    enableCrashlytics: true,
    enableAppCheck: true,
    appCheckDebugMode: false,
  );

  final Environment environment;
  final bool enableCrashlytics;
  final bool enableAppCheck;
  final bool appCheckDebugMode;

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;

  @override
  String toString() => 'EnvironmentConfig(${environment.name})';
}
