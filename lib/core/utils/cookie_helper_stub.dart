/// In-memory stub for non-web platforms (and unit tests).
///
/// Production mobile does not rely on cookies for attendance proof; SharedPreferences
/// holds the JSON payload. This map lets VM tests exercise lock-only cookie markers.
final Map<String, String> _memoryCookies = <String, String>{};

void setWebCookie(String key, String value, {int maxAgeSeconds = 31536000}) {
  _memoryCookies[key] = value;
}

String? getWebCookie(String key) => _memoryCookies[key];

bool hasWebCookie(String key) => _memoryCookies.containsKey(key);

void removeWebCookie(String key) {
  _memoryCookies.remove(key);
}

/// Test-only helper to reset the in-memory cookie map between cases.
void clearWebCookieMemoryForTests() {
  _memoryCookies.clear();
}
