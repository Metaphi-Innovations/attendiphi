import 'package:flutter/foundation.dart';

/// Builds public application URLs without a hash fragment.
///
/// Both production hosts are supported:
/// - [firebaseHostingOrigin] — current Firebase Hosting deploy
/// - [customDomainOrigin] — branded main site
class AppUrl {
  AppUrl._();

  /// Firebase Hosting (in active use for admin / reset flows).
  static const firebaseHostingOrigin = 'https://attendiphi-by-metaphi.web.app';

  /// Custom domain (main branded site).
  static const customDomainOrigin = 'https://attendiphi.metaphi.in';

  /// Default / canonical origin while Firebase Hosting is the primary deploy.
  static const productionOrigin = firebaseHostingOrigin;

  static const productionOrigins = <String>{
    firebaseHostingOrigin,
    customDomainOrigin,
  };

  /// Origin for portal / welcome-email links: current browser host when it is
  /// one of [productionOrigins], otherwise [productionOrigin].
  static String get portalOrigin {
    if (kIsWeb && Uri.base.hasScheme && Uri.base.host.isNotEmpty) {
      final origin = Uri.base.origin.replaceAll(RegExp(r'/$'), '');
      if (productionOrigins.contains(origin)) return origin;
    }
    return productionOrigin;
  }

  /// Flutter Web password-reset screen. Not Firebase `/__/auth/action`.
  ///
  /// Reset emails land on Firebase Hosting so the link stays stable while
  /// both hosts serve the same app. Firebase Auth authorized domains must
  /// include `attendiphi-by-metaphi.web.app` and `attendiphi.metaphi.in`.
  static const passwordResetActionHandler =
      '$firebaseHostingOrigin/admin-reset-password';

  static bool isAllowedHost(String host) {
    final h = host.trim().toLowerCase();
    return h == 'attendiphi-by-metaphi.web.app' ||
        h == 'attendiphi.metaphi.in' ||
        h == 'localhost' ||
        h == '127.0.0.1';
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

  /// Landing URL the reset email button must use.
  static String passwordResetLanding({
    required String oobCode,
    String? apiKey,
  }) {
    return Uri.parse(passwordResetActionHandler).replace(
      queryParameters: {
        'mode': 'resetPassword',
        'oobCode': oobCode,
        if (apiKey != null && apiKey.trim().isNotEmpty) 'apiKey': apiKey.trim(),
      },
    ).toString();
  }

  /// Rewrites a Firebase hosted action URL to the Flutter reset screen.
  ///
  /// Identity Toolkit `oobLink` values look like
  /// `https://…/__/auth/action?mode=resetPassword&oobCode=…&apiKey=…`.
  /// The oob code stays the Firebase code; only the host/path change.
  static String flutterResetUrlFromFirebaseOobLink(String oobLink) {
    final uri = Uri.parse(oobLink.trim());
    final params = Map<String, String>.from(uri.queryParameters);
    if (uri.fragment.contains('?')) {
      params.addAll(
        Uri.splitQueryString(uri.fragment.substring(uri.fragment.indexOf('?') + 1)),
      );
    }
    final oobCode = (params['oobCode'] ?? '').trim();
    if (oobCode.isEmpty) {
      throw const FormatException('Firebase reset link is missing oobCode');
    }
    return passwordResetLanding(
      oobCode: oobCode,
      apiKey: params['apiKey'],
    );
  }

  static bool isFirebasePasswordResetMode(String? mode) =>
      (mode ?? '').trim() == 'resetPassword';
}
