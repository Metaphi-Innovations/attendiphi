import 'app/config/environment.dart';
import 'main.dart';

/// Staging environment entry point.
/// CI/CD smoke marker: 2026-10-27 — verify staging pipeline deploy.
void main() {
  bootstrap(config: EnvironmentConfig.staging);
}
