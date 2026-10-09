/// Minimal public QR directory fields for [AppConstants.publicMembersCollection].
///
/// Presence in `publicMembers` means the member is active and selectable in QR
/// typeahead. Inactive employees remain only on admin-only `employees`.
/// Never include email, photoUrl, biometrics, or admin metadata.
enum PublicMemberProjectionAction {
  /// Create or merge the public doc (`isActive: true`).
  upsert,

  /// Remove the public doc so anonymous clients cannot discover it.
  remove,
}

class PublicMemberProjection {
  PublicMemberProjection._();

  static const allowedKeys = <String>{
    'id',
    'name',
    'phone',
    'isActive',
    'updatedAt',
  };

  /// Active employees are projected; inactive/deleted are omitted from public.
  static PublicMemberProjectionAction actionFor({required bool isActive}) {
    return isActive
        ? PublicMemberProjectionAction.upsert
        : PublicMemberProjectionAction.remove;
  }

  /// Firestore payload for an **active** public member doc.
  ///
  /// Always writes `isActive: true`. Callers must [actionFor] remove when
  /// the employee is inactive instead of writing `isActive: false`.
  static Map<String, dynamic> toMap({
    required String id,
    required String name,
    required String phone,
    DateTime? updatedAt,
  }) {
    return {
      'id': id.trim(),
      'name': name.trim(),
      'phone': phone.trim(),
      'isActive': true,
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  /// True when [keys] contain only approved public fields.
  static bool keysAreAllowed(Iterable<String> keys) {
    for (final key in keys) {
      if (!allowedKeys.contains(key)) return false;
    }
    return true;
  }
}
