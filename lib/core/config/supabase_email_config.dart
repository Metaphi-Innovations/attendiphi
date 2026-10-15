import 'supabase_app_config.dart';

/// Public Supabase configuration for the Attendiphi email Edge Function.
///
/// Uses the same Attendiphi data project as Auth/Postgres
/// (`fzghxzybyygslfjyfewu`). The anon key is a publishable browser key.
/// Never put SMTP passwords or other email-provider secrets here.
class SupabaseEmailConfig {
  SupabaseEmailConfig._();

  static const functionName = 'send-attendiphi-email';
  static const functionNamePath = '/functions/v1/$functionName';

  /// Attendiphi data + Auth project (same as [SupabaseAppConfig]).
  static String get productionUrl => SupabaseAppConfig.url;

  /// Publishable anon / gateway key for the data project.
  static String get productionPublishableKey => SupabaseAppConfig.anonKey;

  static const dartDefinedUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const dartDefinedAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
}

class BrowserSupabaseConfig {
  const BrowserSupabaseConfig({this.url = '', this.anonKey = ''});

  final String url;
  final String anonKey;
}
