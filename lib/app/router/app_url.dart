import 'package:flutter/foundation.dart';

import '../../core/config/supabase_app_config.dart';
import '../config/environment.dart';

/// Builds public application URLs without a hash fragment.
///
/// Production host is the branded nginx site. Firebase Hosting is not used.
class AppUrl {
  AppUrl._();

  /// Canonical production origin (devops deploys `build/web` here).
  static const productionOrigin = 'https://attendiphi.metaphi.in';

  /// Staging website origin (devops deploys staging zip here).
  static const stagingOrigin = 'https://attendiphi.staging.metaphi.in';

  /// Staging hostname (no scheme).
  static const stagingHost = 'attendiphi.staging.metaphi.in';

  /// Alias kept for call sites that previously named the custom domain.
  static const customDomainOrigin = productionOrigin;

  static const productionOrigins = <String>{
    productionOrigin,
    'http://localhost',
    'http://127.0.0.1',
  };

  /// Origin for portal / welcome-email links.
  static String get portalOrigin {
    switch (SupabaseAppConfig.environment) {
      case Environment.development:
        if (kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
          final origin = Uri.base.origin.replaceAll(RegExp(r'/$'), '');
          if (isAllowedHost(Uri.parse(origin).host)) return origin;
        }
        return productionOrigin;
      case Environment.staging:
        if (kIsWeb && _isStagingWebHost(Uri.base.host)) {
          return Uri.base.origin.replaceAll(RegExp(r'/$'), '');
        }
        return stagingOrigin;
      case Environment.production:
        if (kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
          final origin = Uri.base.origin.replaceAll(RegExp(r'/$'), '');
          if (isAllowedHost(Uri.parse(origin).host) &&
              Uri.parse(origin).host.toLowerCase() == 'attendiphi.metaphi.in') {
            return origin;
          }
        }
        return productionOrigin;
    }
  }

  /// Flutter Web password-reset screen (Supabase recovery redirect target).
  static const passwordResetActionHandler =
      '$productionOrigin/admin-reset-password';

  static bool isAllowedHost(String host) {
    final h = host.trim().toLowerCase();
    return h == 'attendiphi.metaphi.in' ||
        _isStagingWebHost(h) ||
        h == 'localhost' ||
        h == '127.0.0.1';
  }

  static bool _isStagingWebHost(String host) {
    final h = host.trim().toLowerCase();
    return h == stagingHost || h == 'attendiphi_staging.metaphi.in';
  }

  /// Origin for QR / public check-in links (must match HMAC environment).
  ///
  /// - **development** → current browser origin (localhost)
  /// - **staging** → [stagingOrigin] (or current origin if already on staging host)
  /// - **production** → [productionOrigin]
  static String get checkInOrigin {
    switch (SupabaseAppConfig.environment) {
      case Environment.development:
        if (kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
          return Uri.base.origin.replaceAll(RegExp(r'/$'), '');
        }
        return 'http://127.0.0.1';
      case Environment.staging:
        if (kIsWeb && _isStagingWebHost(Uri.base.host)) {
          return Uri.base.origin.replaceAll(RegExp(r'/$'), '');
        }
        return stagingOrigin;
      case Environment.production:
        return productionOrigin;
    }
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

  /// Public check-in / QR standee URL for the current environment.
  static String checkInPublic({
    required String path,
    Map<String, String>? queryParameters,
  }) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final parsed = Uri.parse(checkInOrigin);
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
