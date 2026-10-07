import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/check_in_restrictions_config.dart';

/// Reads/writes `appConfig/checkInRestrictions`.
abstract class AppConfigRemoteDataSource {
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions();
  Future<void> setCheckInRestrictions({
    required bool restrictionsEnabled,
    required String updatedBy,
    String? updatedByEmail,
  });
}

class AppConfigRemoteDataSourceImpl implements AppConfigRemoteDataSource {
  AppConfigRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection(AppConstants.appConfigCollection)
      .doc(AppConstants.checkInRestrictionsDocId);

  @override
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions() {
    return _doc.snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return CheckInRestrictionsConfig.defaults;
      }
      final data = snap.data()!;
      return CheckInRestrictionsConfig(
        restrictionsEnabled: data['restrictionsEnabled'] != false,
        updatedAt: _asDateTime(data['updatedAt']),
        updatedBy: (data['updatedBy'] as String?)?.trim(),
        updatedByEmail: (data['updatedByEmail'] as String?)?.trim(),
      );
    });
  }

  @override
  Future<void> setCheckInRestrictions({
    required bool restrictionsEnabled,
    required String updatedBy,
    String? updatedByEmail,
  }) async {
    await _doc.set(
      {
        'restrictionsEnabled': restrictionsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy.trim(),
        if (updatedByEmail != null && updatedByEmail.trim().isNotEmpty)
          'updatedByEmail': updatedByEmail.trim(),
      },
      SetOptions(merge: true),
    );
  }

  DateTime? _asDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
