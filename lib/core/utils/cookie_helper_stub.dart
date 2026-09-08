/// Stub implementation for non-web platforms.
void setWebCookie(String key, String value, {int maxAgeSeconds = 31536000}) {}

String? getWebCookie(String key) => null;

bool hasWebCookie(String key) => false;

void removeWebCookie(String key) {}
