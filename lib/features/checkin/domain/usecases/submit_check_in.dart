import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../location/domain/entities/location_config.dart';
import '../../../location/domain/usecases/validate_user_proximity.dart';
import '../../data/datasources/notification_dispatch_service.dart';
import '../entities/check_in_submission.dart';
import '../entities/check_in_type.dart';
import '../repositories/check_in_repository.dart';
import '../session_lock_ids.dart';

/// Usecase coordinating validation and submission of an attendance check-in.
class SubmitCheckIn {
  SubmitCheckIn(
    this._repository, {
    this.notificationDispatchService,
    this.nowProvider,
  });

  final CheckInRepository _repository;
  final NotificationDispatchService? notificationDispatchService;
  final DateTime Function()? nowProvider;
  static const _uuid = Uuid();

  Future<CheckInSubmission> call({
    required String name,
    required String phone,
    required CheckInType type,
    required LocationConfig location,
    required ProximityResult proximityResult,
    String? email,
    String? substituteForMember,
    String? companyName,
    String? category,
    String? invitedByMember,
    String? photoBase64,
    String? adminId,
    String? sessionDateStr,
    String? sessionToken,
    String? deviceId,
    String? recognizedMemberId,

    /// Member id being substituted for (locks that member for the session day).
    String? substituteForMemberId,

    /// When false, skips Thursday / QR-date / one-device / GPS enforcement.
    /// Phone uniqueness and required fields still apply.
    bool restrictionsEnabled = true,
  }) async {
    // 1. Validate Form Fields
    final nameError = Validators.validateName(name);
    if (nameError != null) {
      throw const CheckInSubmissionFailedException(
        userMessage: 'Please enter a valid full name.',
        technicalMessage: 'Validation failed: Name is invalid',
      );
    }

    final phoneError = Validators.validatePhone(phone);
    if (phoneError != null) {
      throw const CheckInSubmissionFailedException(
        userMessage: 'Please enter a valid 10-digit Indian phone number.',
        technicalMessage: 'Validation failed: Phone number is invalid',
      );
    }

    // 2. Validate substitute photo requirement
    if (type.isSubstitute) {
      if (photoBase64 == null || photoBase64.isEmpty) {
        throw const MissingSubstitutePhotoException();
      }
    }

    // 3. Validate visitor requirements
    if (type.isVisitor) {
      if (email == null ||
          email.trim().isEmpty ||
          Validators.validateEmail(email) != null) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please enter a valid email address.',
          technicalMessage: 'Validation failed: email is invalid for visitor',
        );
      }
      if (companyName == null || companyName.trim().isEmpty) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please enter your company name.',
          technicalMessage:
              'Validation failed: companyName is required for visitor',
        );
      }
      if (category == null || category.trim().isEmpty) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please enter your business category.',
          technicalMessage:
              'Validation failed: category is required for visitor',
        );
      }
      if (invitedByMember == null || invitedByMember.trim().isEmpty) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please select which Member invited you.',
          technicalMessage:
              'Validation failed: invitedByMember is required for visitor',
        );
      }
    }

    // 4. Strict Thursday-Only + QR session date (when restrictions ON)
    final now = nowProvider != null ? nowProvider!() : DateTime.now();

    final parsedSessionDate = () {
      final raw = sessionDateStr?.trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }();

    if (restrictionsEnabled) {
      if (now.weekday != DateTime.thursday) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Check-in is available on Thursday only.',
          technicalMessage: 'Check-in rejected: Today is not Thursday',
        );
      }

      if (parsedSessionDate != null) {
        final isSameDate =
            parsedSessionDate.year == now.year &&
            parsedSessionDate.month == now.month &&
            parsedSessionDate.day == now.day;
        if (!isSameDate) {
          throw const CheckInSubmissionFailedException(
            userMessage: 'This check-in QR session is not valid for today.',
            technicalMessage:
                'Check-in rejected: QR session date does not match today',
          );
        }
      }
    }

    // Attribute attendance to the QR session calendar day (so Daily Attendance /
    // Overview show the check-in under that session when restrictions are OFF).
    // Keep wall-clock time from "now" for ordering within the day.
    final submissionTimestamp = parsedSessionDate != null
        ? DateTime(
            parsedSessionDate.year,
            parsedSessionDate.month,
            parsedSessionDate.day,
            now.hour,
            now.minute,
            now.second,
            now.millisecond,
          )
        : now;

    final docId = _uuid.v4();

    final trimmedName = name.trim();
    final trimmedSubstituteFor = substituteForMember?.trim();
    final coveredMemberId = type.isSubstitute
        ? (substituteForMemberId?.trim().isNotEmpty == true
              ? substituteForMemberId!.trim()
              : null)
        : recognizedMemberId;

    final submission = CheckInSubmission(
      id: docId,
      locationId: location.id,
      locationName: location.name,
      // Attending person (member self, or the substitute attendee).
      userName: trimmedName,
      userPhone: Validators.formatPhoneWithCountryCode(phone),
      type: type,
      userLatitude: proximityResult.userLatitude,
      userLongitude: proximityResult.userLongitude,
      gpsAccuracy: proximityResult.gpsAccuracy,
      distanceMeters: proximityResult.distanceMeters,
      timestamp: submissionTimestamp,
      userEmail: email?.trim(),
      substituteForMember: trimmedSubstituteFor,
      // Persist attending substitute identity so dashboard remap cannot
      // collapse Member Name == Substitute Name after verify write-back.
      substituteName: type.isSubstitute ? trimmedName : null,
      // Dedicated phone field so member-roster sync cannot overwrite it.
      substitutePhone: type.isSubstitute
          ? Validators.formatPhoneWithCountryCode(phone)
          : null,
      companyName: companyName?.trim(),
      category: category?.trim(),
      invitedByMember: invitedByMember?.trim(),
      photoBase64: photoBase64,
      adminId: adminId,
      deviceId: deviceId,
      // Member self-check-in: own id. Substitute: covered member id.
      memberId: coveredMemberId,
      // Member check-in is manual dropdown selection only (no face verify).
      verificationMethod: recognizedMemberId != null ? 'manual' : null,
      faceVerified: false,
    );

    // 5. Optional best-effort duplicate probe when checkIns are readable (admin).
    // Public QR cannot read checkIns — uniqueness is enforced via session locks
    // claimed atomically with the check-in write below.
    final formattedPhone = Validators.formatPhoneWithCountryCode(phone);

    // Phone uniqueness only — devices/tablets are shared across members.
    // Member uniqueness is enforced via member_session_locks on write.
    try {
      final existingPhoneSubmission = await _repository.getIdentitySubmission(
        formattedPhone,
        submissionTimestamp,
      );
      if (existingPhoneSubmission != null) {
        throw DuplicateCheckInException(
          userMessage:
              'This phone number has already submitted attendance for today.',
          existingSubmissionData: existingPhoneSubmission.toMap(),
        );
      }
    } on DuplicateCheckInException {
      rethrow;
    } catch (_) {
      // Unauthenticated QR clients cannot read checkIns after rules lock-down.
    }

    final sessionDateYmd = SessionLockIds.sessionDateYmd(
      sessionDateStr: sessionDateStr,
      fallbackTimestamp: submissionTimestamp,
    );

    final claimMemberId = () {
      if (type.isMember) {
        final id = recognizedMemberId?.trim() ?? '';
        return id.isEmpty ? null : id;
      }
      if (type.isSubstitute) {
        final id = substituteForMemberId?.trim() ?? '';
        return id.isEmpty ? null : id;
      }
      return null;
    }();

    // 6. Atomic write: phone (+ member) locks + checkIns.
    // Device locks are not used — venue phones are shared across members.
    final stored = type.isMember
        ? submission.copyWith(photoBase64: '')
        : submission;
    await _repository.submitCheckIn(
      stored,
      enforceThursday: restrictionsEnabled,
      sessionDateYmd: sessionDateYmd,
      claimDeviceId: null,
      claimMemberId: claimMemberId,
      sessionToken: sessionToken,
    );

    // 6. Trigger Admin Push Notification dispatch (non-blocking)
    if (notificationDispatchService != null) {
      unawaited(
        notificationDispatchService!.dispatchAdminCheckInNotification(
          submission,
        ),
      );
    }

    return submission;
  }
}
