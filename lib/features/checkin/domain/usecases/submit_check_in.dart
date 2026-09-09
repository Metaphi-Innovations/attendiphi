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
    String? deviceId,
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
      if (email == null || email.trim().isEmpty || Validators.validateEmail(email) != null) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please enter a valid email address.',
          technicalMessage: 'Validation failed: email is invalid for visitor',
        );
      }
      if (companyName == null || companyName.trim().isEmpty) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please enter your company name.',
          technicalMessage: 'Validation failed: companyName is required for visitor',
        );
      }
      if (category == null || category.trim().isEmpty) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please enter your business category.',
          technicalMessage: 'Validation failed: category is required for visitor',
        );
      }
      if (invitedByMember == null || invitedByMember.trim().isEmpty) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Please select which Member invited you.',
          technicalMessage: 'Validation failed: invitedByMember is required for visitor',
        );
      }
    }

    // 4. Strict Thursday-Only Business Rule Validation
    final now = nowProvider != null ? nowProvider!() : DateTime.now();
    if (now.weekday != DateTime.thursday) {
      throw const CheckInSubmissionFailedException(
        userMessage: 'Check-in is available on Thursday only.',
        technicalMessage: 'Check-in rejected: Today is not Thursday',
      );
    }

    // Validate QR session date matches current Thursday session
    if (sessionDateStr != null && sessionDateStr.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(sessionDateStr.trim());
      if (parsed != null) {
        final isSameDate = parsed.year == now.year &&
            parsed.month == now.month &&
            parsed.day == now.day;
        if (!isSameDate) {
          throw const CheckInSubmissionFailedException(
            userMessage: 'This check-in QR session is not valid for today.',
            technicalMessage:
                'Check-in rejected: QR session date does not match today',
          );
        }
      }
    }

    final submissionTimestamp = now;

    final docId = _uuid.v4();

    final submission = CheckInSubmission(
      id: docId,
      locationId: location.id,
      locationName: location.name,
      userName: name.trim(),
      userPhone: Validators.formatPhoneWithCountryCode(phone),
      type: type,
      userLatitude: proximityResult.userLatitude,
      userLongitude: proximityResult.userLongitude,
      gpsAccuracy: proximityResult.gpsAccuracy,
      distanceMeters: proximityResult.distanceMeters,
      timestamp: submissionTimestamp,
      userEmail: email?.trim(),
      substituteForMember: substituteForMember?.trim(),
      companyName: companyName?.trim(),
      category: category?.trim(),
      invitedByMember: invitedByMember?.trim(),
      photoBase64: photoBase64,
      adminId: adminId,
      deviceId: deviceId,
    );

    // 5. Server-side duplicate validation based on Identity (Phone)
    final formattedPhone = Validators.formatPhoneWithCountryCode(phone);
    final existingSubmission = await _repository.getIdentitySubmission(
      formattedPhone,
      submissionTimestamp,
    );
    if (existingSubmission != null) {
      throw DuplicateCheckInException(
        existingSubmissionData: existingSubmission.toMap(),
      );
    }

    // 5b. Server-side duplicate validation based on Device ID
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      final existingDeviceSubmission = await _repository.getDeviceSubmission(
        deviceId.trim(),
        submissionTimestamp,
      );
      if (existingDeviceSubmission != null) {
        throw DuplicateCheckInException(
          existingSubmissionData: existingDeviceSubmission.toMap(),
        );
      }
    }

    // 6. Save to Firestore
    await _repository.submitCheckIn(submission);

    // 6. Trigger Admin Push Notification dispatch (non-blocking)
    if (notificationDispatchService != null) {
      unawaited(notificationDispatchService!.dispatchAdminCheckInNotification(submission));
    }

    return submission;
  }
}
