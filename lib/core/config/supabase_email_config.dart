/// Public Supabase configuration for the Attendiphi email Edge Function.
///
/// The anon key is a publishable browser key, like the Firebase web API key.
/// Never put SMTP passwords or other email-provider secrets here.
class SupabaseEmailConfig {
  SupabaseEmailConfig._();

  static const firebaseProjectId = 'qr-checkin-dev';
  static const functionName = 'send-attendiphi-email';
  static const functionNamePath = '/functions/v1/$functionName';

  /// Hosted Edge Function project. Not a Firebase replacement.
  static const productionUrl = 'https://ktnhyohshdwqvvlgeynp.supabase.co';

  /// Publishable gateway key (`apikey` header). Not an SMTP password.
  static const productionPublishableKey =
      'sb_publishable_PsUeIywCm_AlwmVBVEIZ5A_Y_44_o3i';

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
