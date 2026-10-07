import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../location/domain/entities/location_config.dart';
import '../../../location/domain/usecases/validate_user_proximity.dart';
import '../../data/datasources/device_checkin_service.dart';

import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';
import 'checkin_form_state.dart';
import 'checkin_providers.dart';

/// Riverpod StateNotifier managing the Check-In form inputs, photo, and submission.
class CheckInFormNotifier extends Notifier<CheckInFormState> {
  @override
  CheckInFormState build() {
    return const CheckInFormState();
  }

  void setName(String name) {
    state = state.copyWith(name: name, clearError: true);
  }

  void setPhone(String phone) {
    state = state.copyWith(phone: phone, clearError: true);
  }

  void setEmail(String email) {
    state = state.copyWith(email: email, clearError: true);
  }

  void setType(CheckInType type) {
    state = state.copyWith(type: type, clearError: true);
  }

  void setSubstituteForMember(String? member) {
    state = state.copyWith(substituteForMember: member, clearError: true);
  }

  void setCompanyName(String companyName) {
    state = state.copyWith(companyName: companyName, clearError: true);
  }

  void setCategory(String category) {
    state = state.copyWith(category: category, clearError: true);
  }

  void setInvitedByMember(String? member) {
    state = state.copyWith(invitedByMember: member, clearError: true);
  }

  void setPhotoBase64(String? base64) {
    state = state.copyWith(photoBase64: base64, clearError: true);
  }

  void clearPhoto() {
    state = state.copyWith(clearPhoto: true, clearError: true);
  }

  void setAdminId(String? adminId) {
    state = state.copyWith(adminId: adminId, clearError: true);
  }

  void setRecognizedMember(String? memberId) {
    if (memberId == null || memberId.isEmpty) {
      state = state.copyWith(clearRecognizedMember: true, clearError: true);
      return;
    }
    state = state.copyWith(recognizedMemberId: memberId, clearError: true);
  }

  /// Drops name/phone/email/photo/recognized id so the next person on a
  /// shared phone cannot inherit the previous member.
  void clearIdentity() {
    state = state.copyWith(clearIdentity: true, clearError: true);
  }

  /// Submits the attendance record to Firestore and records it locally on this device.

  Future<bool> submit({
    required LocationConfig location,
    required ProximityResult proximityResult,
    String? sessionDateStr,
  }) async {
    if (state.type == null) {
      state = state.copyWith(type: CheckInType.member);
    }

    final deviceService = ref.read(deviceCheckInServiceProvider);
    final restrictionsEnabled = ref.read(restrictionsEnabledProvider);

    // One device = one check-in only while production restrictions are ON.
    if (restrictionsEnabled) {
      final hasCheckedIn = await deviceService.hasCheckedInForSession(
        sessionDateStr: sessionDateStr,
        locationId: location.id,
        probeServer: true,
      );

      if (hasCheckedIn) {
        final existingSubmission = await deviceService.getSubmissionForSession(
          sessionDateStr: sessionDateStr,
          locationId: location.id,
          probeServer: false,
        );

        state = state.copyWith(
          isSubmitting: false,
          error: DuplicateCheckInException(
            userMessage:
                'This device has already recorded attendance for today.',
            existingSubmissionData: existingSubmission?.toMap(),
          ),
          submissionResult: existingSubmission,
        );
        return false;
      }
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final deviceId = await deviceService.getOrCreateDeviceId();
      final submitUseCase = ref.read(submitCheckInUseCaseProvider);
      final submission = await submitUseCase(
        name: state.name,
        phone: state.phone,
        type: state.type!,
        location: location,
        proximityResult: proximityResult,
        email: state.email,
        substituteForMember: state.substituteForMember,
        companyName: state.companyName,
        category: state.category,
        invitedByMember: state.invitedByMember,
        photoBase64: state.photoBase64,
        adminId: state.adminId,
        sessionDateStr: sessionDateStr,
        deviceId: deviceId,
        recognizedMemberId: state.recognizedMemberId,
        restrictionsEnabled: restrictionsEnabled,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw const ServerException(
            userMessage:
                'Network is slow. Your face was verified — tap Member to try saving again.',
            technicalMessage: 'SubmitCheckIn timed out after 12s',
          );
        },
      );

      // 2. Persist submission locally on device to prevent future duplicate submissions
      await deviceService.recordSubmission(
        sessionDateStr: sessionDateStr,
        submission: submission,
      );

      state = state.copyWith(
        isSubmitting: false,
        submissionResult: submission,
      );

      AppLogger.info(
        'Check-in success for ${submission.userName} (${submission.type.displayName}) at ${submission.locationName}',
        tag: 'CheckInFormNotifier',
      );
      return true;
    } on DuplicateCheckInException catch (e) {
      CheckInSubmission? existingSub;
      if (e.existingSubmissionData != null) {
        try {
          existingSub = CheckInSubmission.fromMap(e.existingSubmissionData!);
        } catch (_) {}
      }
      state = state.copyWith(
        isSubmitting: false,
        error: e,
        submissionResult: existingSub,
      );
      return false;
    } on AppException catch (e) {
      AppLogger.logException(e, tag: 'CheckInFormNotifier');
      state = state.copyWith(isSubmitting: false, error: e);
      return false;
    } catch (e, st) {
      AppLogger.error(
        'Unexpected submission error: $e',
        error: e,
        stackTrace: st,
        tag: 'CheckInFormNotifier',
      );
      state = state.copyWith(
        isSubmitting: false,
        error: ServerException(
          technicalMessage: 'Submission failed: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
      return false;
    }
  }

  /// Resets the form back to initial state.
  void reset() {
    state = const CheckInFormState();
  }
}


/// Provider for [CheckInFormNotifier].
final checkInFormProvider =
    NotifierProvider<CheckInFormNotifier, CheckInFormState>(() {
  return CheckInFormNotifier();
});
