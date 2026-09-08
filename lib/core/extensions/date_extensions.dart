import 'package:intl/intl.dart';

/// DateTime formatting extensions.
extension DateExtensions on DateTime {
  /// Formats as "Aug 26, 2026"
  String get formattedDate => DateFormat.yMMMd().format(this);

  /// Formats as "1:30 PM"
  String get formattedTime => DateFormat.jm().format(this);

  /// Formats as "Aug 26, 2026 at 1:30 PM"
  String get formattedDateTime =>
      '${DateFormat.yMMMd().format(this)} at ${DateFormat.jm().format(this)}';

  /// Formats as "26/08/2026"
  String get formattedDateShort => DateFormat('dd/MM/yyyy').format(this);

  /// Returns a relative time string (e.g., "2 min ago", "1 hr ago").
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins min${mins == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hrs = difference.inHours;
      return '$hrs hr${hrs == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    } else {
      return formattedDate;
    }
  }
}
