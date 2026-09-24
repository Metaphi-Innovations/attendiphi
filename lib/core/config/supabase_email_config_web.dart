import 'dart:js_interop';

import 'supabase_email_config.dart';

@JS('__attendiphiSupabaseUrl')
external JSString? _jsUrl();

@JS('__attendiphiSupabaseAnonKey')
external JSString? _jsAnonKey();

Future<BrowserSupabaseConfig> readBrowserSupabaseConfig() async {
  try {
    return BrowserSupabaseConfig(
      url: _jsUrl()?.toDart.trim() ?? '',
      anonKey: _jsAnonKey()?.toDart.trim() ?? '',
    );
  } catch (_) {
    return const BrowserSupabaseConfig();
  }
}
