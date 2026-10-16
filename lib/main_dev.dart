import 'app/config/environment.dart';
import 'main.dart';

/// Local Docker Supabase entry point (Stage 1).
///
/// Prefer `./scripts/run_web_local.sh`.
void main() {
  bootstrap(config: EnvironmentConfig.development);
}
