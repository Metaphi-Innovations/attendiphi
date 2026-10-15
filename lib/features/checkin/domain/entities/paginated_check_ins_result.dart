import 'check_in_submission.dart';

/// Result container for cursor-based pagination of check-in submissions.
///
/// [lastDocument] is backend-specific:
/// - Firestore: `DocumentSnapshot`
/// - Supabase: `String` keyset cursor (`"$iso|$id"`)
class PaginatedCheckInsResult {
  const PaginatedCheckInsResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  /// The check-in items loaded in the current page.
  final List<CheckInSubmission> items;

  /// Opaque pagination cursor for the next page request.
  final Object? lastDocument;

  /// Whether there are additional records to fetch in subsequent pages.
  final bool hasMore;
}
