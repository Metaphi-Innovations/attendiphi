import 'cookie_helper_stub.dart'
    if (dart.library.html) 'cookie_helper_web.dart' as platform;

/// Cross-platform cookie helper to ensure Web sessions (especially Safari/iOS)
/// persist across browser contexts, private windows, and Safari View Controllers.
class CookieHelper {
  CookieHelper._();

  /// Sets a persistent cookie for the session.
  static void setCookie(
    String key,
    String value, {
    int maxAgeSeconds = 31536000,
  }) {
    platform.setWebCookie(key, value, maxAgeSeconds: maxAgeSeconds);
  }

  /// Retrieves a cookie value by key.
  static String? getCookie(String key) {
    return platform.getWebCookie(key);
  }

  /// Checks if a cookie key exists.
  static bool hasCookie(String key) {
    return platform.hasWebCookie(key);
  }

  /// Removes a cookie by key.
  static void removeCookie(String key) {
    platform.removeWebCookie(key);
  }
}
