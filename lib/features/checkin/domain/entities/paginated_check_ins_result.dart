import 'package:cloud_firestore/cloud_firestore.dart';

import 'check_in_submission.dart';

/// Result container for cursor-based Firestore pagination of check-in submissions.
class PaginatedCheckInsResult {
  const PaginatedCheckInsResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  /// The check-in items loaded in the current page.
  final List<CheckInSubmission> items;

  /// The cursor snapshot pointing to the last document in this page.
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  /// Whether there are additional records to fetch in subsequent pages.
  final bool hasMore;
}
