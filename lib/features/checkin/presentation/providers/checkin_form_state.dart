import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';

/// Form state for attendance check-in.
/// [type] defaults to [CheckInType.member] so the Member tab starts selected.
class CheckInFormState {
  const CheckInFormState({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.type = CheckInType.member,
    this.substituteForMember,
    this.companyName = '',
    this.category = '',
    this.invitedByMember,
    this.photoBase64,
    this.adminId,
    this.isSubmitting = false,
    this.submissionResult,
    this.error,
    this.recognizedMemberId,
  });

  final String name;
  final String phone;
  final String email;
  final CheckInType? type;
  final String? substituteForMember;
  final String companyName;
  final String category;
  final String? invitedByMember;
  final String? photoBase64;
  final String? adminId;
  final bool isSubmitting;
  final CheckInSubmission? submissionResult;
  final AppException? error;

  /// Member id last verified from a live selfie in this form session.
  final String? recognizedMemberId;

  bool get isMember => type == CheckInType.member;
  bool get isSubstitute => type == CheckInType.substitute;
  bool get isVisitor => type == CheckInType.visitor;
  bool get hasSelectedType => type != null;
  bool get hasPhoto => photoBase64 != null && photoBase64!.isNotEmpty;

  CheckInFormState copyWith({
    String? name,
    String? phone,
    String? email,
    CheckInType? type,
    String? substituteForMember,
    String? companyName,
    String? category,
    String? invitedByMember,
    String? photoBase64,
    String? adminId,
    bool? isSubmitting,
    CheckInSubmission? submissionResult,
    AppException? error,
    String? recognizedMemberId,
    bool clearError = false,
    bool clearPhoto = false,
    bool clearRecognizedMember = false,
    bool clearIdentity = false,
  }) {
    return CheckInFormState(
      name: clearIdentity ? '' : (name ?? this.name),
      phone: clearIdentity ? '' : (phone ?? this.phone),
      email: clearIdentity ? '' : (email ?? this.email),
      type: type ?? this.type,
      substituteForMember: substituteForMember ?? this.substituteForMember,
      companyName: companyName ?? this.companyName,
      category: category ?? this.category,
      invitedByMember: invitedByMember ?? this.invitedByMember,
      photoBase64: (clearPhoto || clearIdentity)
          ? null
          : (photoBase64 ?? this.photoBase64),
      adminId: adminId ?? this.adminId,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionResult: submissionResult ?? this.submissionResult,
      error: clearError ? null : (error ?? this.error),
      recognizedMemberId: (clearRecognizedMember || clearIdentity)
          ? null
          : (recognizedMemberId ?? this.recognizedMemberId),
    );
  }
}
