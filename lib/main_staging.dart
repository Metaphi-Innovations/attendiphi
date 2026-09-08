import 'app/config/environment.dart';
import 'main.dart';

/// Staging environment entry point.
void main() {
  bootstrap(config: EnvironmentConfig.staging);
}
