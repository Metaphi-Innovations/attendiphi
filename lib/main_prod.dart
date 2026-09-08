import 'app/config/environment.dart';
import 'main.dart';

/// Production environment entry point.
void main() {
  bootstrap(config: EnvironmentConfig.production);
}
