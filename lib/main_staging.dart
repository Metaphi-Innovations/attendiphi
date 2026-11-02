import 'app/config/environment.dart';
import 'main.dart';

/// Cloud staging (attendiphi-test) entry point (Stage 2).
///
/// Used by `./scripts/run_web_staging.sh` and `./scripts/build_web_staging.sh`
/// (staging site → attendiphi.staging.metaphi.in). See [docs/ENVIRONMENTS.md].
void main() {
  bootstrap(config: EnvironmentConfig.staging);
}
