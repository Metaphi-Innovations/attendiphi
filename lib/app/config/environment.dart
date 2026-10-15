/// Application environment configuration.
///
/// Environments share the same Supabase backend by default; flags control
/// logging / optional crash reporting only.
enum Environment { development, staging, production }

/// Holds the current environment configuration.
class EnvironmentConfig {
  const EnvironmentConfig._({
    required this.environment,
    required this.enableCrashReporting,
  });

  /// Development configuration.
  static const development = EnvironmentConfig._(
    environment: Environment.development,
    enableCrashReporting: false,
  );

  /// Staging configuration.
  static const staging = EnvironmentConfig._(
    environment: Environment.staging,
    enableCrashReporting: true,
  );

  /// Production configuration.
  static const production = EnvironmentConfig._(
    environment: Environment.production,
    enableCrashReporting: true,
  );

  final Environment environment;

  /// When true, [CrashReporting.init] is called (requires `SENTRY_DSN`).
  final bool enableCrashReporting;

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;

  @override
  String toString() => 'EnvironmentConfig(${environment.name})';
}
