import 'package:flutter/foundation.dart';

/// Builds public application URLs without a hash fragment.
///
/// Production host is the branded nginx site. Firebase Hosting is not used.
class AppUrl {
  AppUrl._();

  /// Canonical production origin (devops deploys `build/web` here).
  static const productionOrigin = 'https://attendiphi.metaphi.in';

  /// Alias kept for call sites that previously named the custom domain.
  static const customDomainOrigin = productionOrigin;

  static const productionOrigins = <String>{
    productionOrigin,
    'http://localhost',
    'http://127.0.0.1',
  };

  /// Origin for portal / welcome-email links: current browser host when it is
  /// an allowed production host, otherwise [productionOrigin].
  static String get portalOrigin {
    if (kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
      final origin = Uri.base.origin.replaceAll(RegExp(r'/$'), '');
      if (isAllowedHost(Uri.parse(origin).host)) return origin;
    }
    return productionOrigin;
  }

  /// Flutter Web password-reset screen (Supabase recovery redirect target).
  static const passwordResetActionHandler =
      '$productionOrigin/admin-reset-password';

  static bool isAllowedHost(String host) {
    final h = host.trim().toLowerCase();
    return h == 'attendiphi.metaphi.in' || h == 'localhost' || h == '127.0.0.1';
  }

  /// Returns `https://host/path?query` with no `#`.
  static String public({
    required String path,
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final origin = kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty
        ? Uri.base.origin
        : productionOrigin;
    final parsed = Uri.parse(origin);
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: normalizedPath,
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    ).toString();
  }

  /// Public check-in / QR standee URLs always target [productionOrigin].
  static String checkInPublic({
    required String path,
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final parsed = Uri.parse(productionOrigin);
    return Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: parsed.hasPort ? parsed.port : null,
      path: normalizedPath,
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    ).toString();
  }

  /// Landing URL after Supabase sends a recovery email (query params optional).
  static String passwordResetLanding({String? oobCode, String? apiKey}) {
    return Uri.parse(passwordResetActionHandler)
        .replace(
          queryParameters: {
            if (oobCode != null && oobCode.trim().isNotEmpty)
              'oobCode': oobCode.trim(),
            if (apiKey != null && apiKey.trim().isNotEmpty)
              'apiKey': apiKey.trim(),
          },
        )
        .toString();
  }
}
