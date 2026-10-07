import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/paginated_check_ins_result.dart';

/// Remote data source writing check-ins to Cloud Firestore.
abstract class CheckInRemoteDataSource {
  Future<void> createCheckIn(
    CheckInSubmission submission, {
    bool enforceThursday = true,
  });
  Future<void> updateCheckIn(CheckInSubmission submission);
  Future<void> deleteCheckIn(String checkInId);
  Future<void> deleteAllCheckIns({String? locationId});
  Stream<List<CheckInSubmission>> streamCheckIns({String? locationId});
  Future<PaginatedCheckInsResult> getPaginatedCheckIns({
    int limit = AppConstants.dashboardPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? locationId,
  });
  Future<bool> hasIdentityCheckedIn(String phone, DateTime sessionDate);
  Future<CheckInSubmission?> getIdentitySubmission(String phone, DateTime sessionDate);
  Future<CheckInSubmission?> getDeviceSubmission(String deviceId, DateTime sessionDate);

  /// Creates `deviceSessionLocks/{deviceId}_{sessionDate}` once. Fails if already claimed.
  Future<void> claimDeviceSessionLock({
    required String deviceId,
    required String sessionDateYmd,
  });

  /// Checks if a device session lock exists for `deviceSessionLocks/{deviceId}_{sessionDate}`.
  Future<bool> isDeviceSessionLocked({
    required String deviceId,
    required String sessionDateYmd,
  });
}

/// Cloud Firestore implementation of [CheckInRemoteDataSource].
class CheckInRemoteDataSourceImpl implements CheckInRemoteDataSource {
  CheckInRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> createCheckIn(
    CheckInSubmission submission, {
    bool enforceThursday = true,
  }) async {
    try {
      if (enforceThursday &&
          submission.timestamp.weekday != DateTime.thursday) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Check-in is available on Thursday only.',
          technicalMessage:
              'Check-in rejected: Attendance date must be Thursday',
        );
      }

      final docRef = _firestore
          .collection(AppConstants.checkInsCollection)
          .doc(submission.id);

      await docRef.set({
        ...submission.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw const ServerException(
            userMessage:
                'Network is slow. Your face was verified — tap Member to try saving again.',
            technicalMessage: 'Firestore check-in write timed out after 8s',
          );
        },
      );

      AppLogger.info(
        'Check-in recorded: ${submission.userName} (${submission.type.name}) at ${submission.locationName}',
        tag: 'CheckInRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error recording check-in: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Firestore write error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error recording check-in: $e',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Check-in failed: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> updateCheckIn(CheckInSubmission submission) async {
    try {
      final docRef = _firestore
          .collection(AppConstants.checkInsCollection)
          .doc(submission.id);
          
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        await docRef.update(submission.toMap());
      } else {
        // Upsert dummy 'absent' records that are being manually checked in
        await docRef.set({
          ...submission.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.info(
        'Check-in updated: ${submission.id} (${submission.userName})',
        tag: 'CheckInRemoteDataSource',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error updating check-in: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Firestore update error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteCheckIn(String checkInId) async {
    try {
      await _firestore
          .collection(AppConstants.checkInsCollection)
          .doc(checkInId)
          .delete();

      AppLogger.info(
        'Check-in deleted: $checkInId',
        tag: 'CheckInRemoteDataSource',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error deleting check-in: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Firestore delete error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteAllCheckIns({String? locationId}) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(AppConstants.checkInsCollection);
      if (locationId != null && locationId.isNotEmpty) {
        query = query.where('locationId', isEqualTo: locationId);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      AppLogger.info(
        'Deleted all ${snapshot.docs.length} check-in records',
        tag: 'CheckInRemoteDataSource',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error deleting all check-ins: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage:
            'Firestore delete all error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<CheckInSubmission?> getIdentitySubmission(
    String phone,
    DateTime sessionDate,
  ) async {
    try {
      final normalizedPhone = Validators.normalizePhone(phone);
      final formattedPhone = Validators.formatPhoneWithCountryCode(phone);

      // Match all possible stored formats of the phone number (+91..., 91..., or 10 digits)
      final phoneVariants = <String>{
        formattedPhone,
        normalizedPhone,
        if (normalizedPhone.isNotEmpty) '91$normalizedPhone',
        if (phone.trim().isNotEmpty) phone.trim(),
      }.toList();

      // Query by phone variants only (standard single-field index, never requires composite index)
      final querySnapshot = await _firestore
          .collection(AppConstants.checkInsCollection)
          .where('userPhone', whereIn: phoneVariants)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final tsRaw = data['timestamp'];
        if (_isSameSessionDate(tsRaw, sessionDate)) {
          try {
            return CheckInSubmission.fromMap(data);
          } catch (_) {
            return CheckInSubmission.fromMap({
              ...data,
              'id': doc.id,
            });
          }
        }
      }

      return null;
    } catch (e, st) {
      AppLogger.warning(
        'Error finding identity submission: $e\n$st',
        tag: 'CheckInRemoteDataSource',
      );
      return null;
    }
  }

  @override
  Future<bool> hasIdentityCheckedIn(String phone, DateTime sessionDate) async {
    final submission = await getIdentitySubmission(phone, sessionDate);
    return submission != null;
  }

  @override
  Stream<List<CheckInSubmission>> streamCheckIns({String? locationId}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.checkInsCollection)
        .orderBy('timestamp', descending: true);

    if (locationId != null && locationId.isNotEmpty) {
      query = query.where('locationId', isEqualTo: locationId);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        final ca = data['createdAt'];
        if (ca != null && ca is Timestamp) {
          data['createdAt'] = ca.toDate().toUtc().toIso8601String();
        }
        return CheckInSubmission.fromMap(data);
      }).toList();
    });
  }

  @override
  Future<PaginatedCheckInsResult> getPaginatedCheckIns({
    int limit = AppConstants.dashboardPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? locationId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(AppConstants.checkInsCollection)
          .orderBy('timestamp', descending: true);

      if (locationId != null && locationId.isNotEmpty) {
        query = query.where('locationId', isEqualTo: locationId);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Fetch limit + 1 documents to accurately determine if more items exist
      final snapshot = await query.limit(limit + 1).get();
      final hasMore = snapshot.docs.length > limit;
      final resultDocs =
          hasMore ? snapshot.docs.take(limit).toList() : snapshot.docs;

      final items = resultDocs
          .map((doc) => CheckInSubmission.fromMap(doc.data()))
          .toList();

      final lastDocument = resultDocs.isNotEmpty ? resultDocs.last : null;

      AppLogger.info(
        'Fetched ${items.length} paginated check-ins (hasMore: $hasMore)',
        tag: 'CheckInRemoteDataSource',
      );

      return PaginatedCheckInsResult(
        items: items,
        lastDocument: lastDocument,
        hasMore: hasMore,
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error fetching paginated check-ins: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Firestore read error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error fetching paginated check-ins: $e',
        error: e,
        stackTrace: st,
        tag: 'CheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to fetch check-ins: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<CheckInSubmission?> getDeviceSubmission(
    String deviceId,
    DateTime sessionDate,
  ) async {
    try {
      if (deviceId.isEmpty) return null;

      final querySnapshot = await _firestore
          .collection(AppConstants.checkInsCollection)
          .where('deviceId', isEqualTo: deviceId)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final tsRaw = data['timestamp'];
        if (_isSameSessionDate(tsRaw, sessionDate)) {
          try {
            return CheckInSubmission.fromMap(data);
          } catch (_) {
            return CheckInSubmission.fromMap({
              ...data,
              'id': doc.id,
            });
          }
        }
      }

      return null;
    } catch (e, st) {
      AppLogger.warning(
        'Error finding device submission: $e\n$st',
        tag: 'CheckInRemoteDataSource',
      );
      return null;
    }
  }

  @override
  Future<void> claimDeviceSessionLock({
    required String deviceId,
    required String sessionDateYmd,
  }) async {
    final id = deviceId.trim();
    final date = sessionDateYmd.trim();
    if (id.isEmpty || date.isEmpty) {
      throw const CheckInSubmissionFailedException(
        userMessage: 'Could not verify this device for check-in. Please try again.',
        technicalMessage: 'claimDeviceSessionLock missing deviceId or sessionDate',
      );
    }

    final lockId = '${id}_$date';
    final docRef = _firestore
        .collection(AppConstants.deviceSessionLocksCollection)
        .doc(lockId);

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(docRef);
        if (existing.exists) {
          throw const DuplicateCheckInException(
            userMessage:
                'This device has already recorded attendance for today.',
            technicalMessage: 'deviceSessionLocks already-exists',
          );
        }
        transaction.set(docRef, {
          'deviceId': id,
          'sessionDate': date,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on DuplicateCheckInException {
      rethrow;
    } on FirebaseException catch (e) {
      AppLogger.warning(
        'claimDeviceSessionLock failed: ${e.code}',
        tag: 'CheckInRemoteDataSource',
      );
      rethrow;
    }
  }

  @override
  Future<bool> isDeviceSessionLocked({
    required String deviceId,
    required String sessionDateYmd,
  }) async {
    final id = deviceId.trim();
    final date = sessionDateYmd.trim();
    if (id.isEmpty || date.isEmpty) return false;

    final lockId = '${id}_$date';
    final docRef = _firestore
        .collection(AppConstants.deviceSessionLocksCollection)
        .doc(lockId);

    try {
      final doc = await docRef.get();
      return doc.exists;
    } catch (e, st) {
      AppLogger.warning(
        'isDeviceSessionLocked check failed ($lockId): $e\n$st',
        tag: 'CheckInRemoteDataSource',
      );
      return false;
    }
  }

  /// Checks whether a stored timestamp matches the target session date,
  /// resiliently handling Firestore Timestamps, ISO Strings, and UTC vs IST timezone differences.
  bool _isSameSessionDate(dynamic tsRaw, DateTime sessionDate) {
    if (tsRaw == null) return false;
    DateTime? dt;
    if (tsRaw is Timestamp) {
      dt = tsRaw.toDate();
    } else if (tsRaw is DateTime) {
      dt = tsRaw;
    } else if (tsRaw is String) {
      dt = DateTime.tryParse(tsRaw);
    } else if (tsRaw is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(tsRaw);
    }
    if (dt == null) return false;

    // Check local calendar date match
    final localDt = dt.toLocal();
    final localTarget = sessionDate.toLocal();
    if (localDt.year == localTarget.year &&
        localDt.month == localTarget.month &&
        localDt.day == localTarget.day) {
      return true;
    }

    // Check UTC calendar date match
    final utcDt = dt.toUtc();
    final utcTarget = sessionDate.toUtc();
    if (utcDt.year == utcTarget.year &&
        utcDt.month == utcTarget.month &&
        utcDt.day == utcTarget.day) {
      return true;
    }

    // Fallback: within 18 hours of target session moment
    final diff = dt.difference(sessionDate).abs();
    if (diff <= const Duration(hours: 18)) {
      return true;
    }

    return false;
  }
}
