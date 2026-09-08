// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation using document.cookie, window.localStorage, and window.sessionStorage
/// to ensure reliable persistence on iOS Safari, Safari View Controller, and Android.
void setWebCookie(String key, String value, {int maxAgeSeconds = 315360000}) {
  try {
    final now = DateTime.now();
    final expiry = now.add(Duration(seconds: maxAgeSeconds));
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = days[expiry.toUtc().weekday % 7];
    final monthName = months[expiry.toUtc().month - 1];
    final day = expiry.toUtc().day.toString().padLeft(2, '0');
    final year = expiry.toUtc().year;
    final hour = expiry.toUtc().hour.toString().padLeft(2, '0');
    final minute = expiry.toUtc().minute.toString().padLeft(2, '0');
    final second = expiry.toUtc().second.toString().padLeft(2, '0');
    final expiresGmt =
        '$dayName, $day $monthName $year $hour:$minute:$second GMT';

    final encodedVal = Uri.encodeComponent(value);
    html.document.cookie =
        '$key=$encodedVal; max-age=$maxAgeSeconds; expires=$expiresGmt; path=/; SameSite=Lax; Secure';
  } catch (_) {}

  // Also sync to window.localStorage
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}

  // Also sync to window.sessionStorage
  try {
    html.window.sessionStorage[key] = value;
  } catch (_) {}
}

String? getWebCookie(String key) {
  // 1. Check document.cookie
  try {
    final raw = html.document.cookie;
    if (raw != null && raw.isNotEmpty) {
      final cookies = raw.split(';');
      for (final c in cookies) {
        final parts = c.trim().split('=');
        if (parts.isNotEmpty && parts[0] == key) {
          final val = parts.length > 1 ? parts.sublist(1).join('=') : '';
          try {
            return Uri.decodeComponent(val);
          } catch (_) {
            return val;
          }
        }
      }
    }
  } catch (_) {}

  // 2. Fallback to direct window.localStorage
  try {
    final localVal = html.window.localStorage[key];
    if (localVal != null && localVal.isNotEmpty) {
      return localVal;
    }
  } catch (_) {}

  // 3. Fallback to direct window.sessionStorage
  try {
    final sessionVal = html.window.sessionStorage[key];
    if (sessionVal != null && sessionVal.isNotEmpty) {
      return sessionVal;
    }
  } catch (_) {}

  return null;
}

bool hasWebCookie(String key) {
  final val = getWebCookie(key);
  return val != null && val.isNotEmpty;
}

void removeWebCookie(String key) {
  try {
    html.document.cookie =
        '$key=; max-age=0; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/; SameSite=Lax; Secure';
  } catch (_) {}
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
  try {
    html.window.sessionStorage.remove(key);
  } catch (_) {}
}
