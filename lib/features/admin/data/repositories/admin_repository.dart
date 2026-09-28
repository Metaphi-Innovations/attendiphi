import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/admin_user.dart';
import '../datasources/admin_auth_email.dart';
import '../datasources/admin_remote_data_source.dart';
import '../datasources/email_credentials_service.dart';

abstract class AdminRepository {
  Stream<List<AdminUser>> watchAdmins({String? createdBy});
  Future<List<AdminUser>> getAdmins({String? createdBy});
  Future<AdminUser?> getAdminByEmail(String email);
  Future<AdminUser?> getAdminById(String id);
  Future<AdminUser> createAdmin({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  });
  Future<void> updateAdmin(AdminUser admin);
  Future<void> toggleAdminActive(String adminId, bool isActive);
  Future<void> deleteAdmin(String adminId, {String? email});
  Future<SendCredentialsResult> sendCredentials({
    required AdminUser admin,
    required String password,
    required String senderEmail,
    required String senderPassword,
    required String idempotencyKey,
    void Function(String phase)? onProgress,
  });
}

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({
    required this.remoteDataSource,
    required this.emailService,
    Future<String?> Function(String email, {String? password})? provisionAuthUserFn,
  }) : _provisionAuthUserFn =
            provisionAuthUserFn ?? AdminAuthEmailClient.provisionAuthUser;

  final AdminRemoteDataSource remoteDataSource;
  final EmailCredentialsService emailService;
  final Future<String?> Function(String email, {String? password})
      _provisionAuthUserFn;

  @override
  Stream<List<AdminUser>> watchAdmins({String? createdBy}) =>
      remoteDataSource.watchAdmins(createdBy: createdBy);

  @override
  Future<List<AdminUser>> getAdmins({String? createdBy}) =>
      remoteDataSource.getAdmins(createdBy: createdBy);

  @override
  Future<AdminUser?> getAdminByEmail(String email) =>
      remoteDataSource.getAdminByEmail(email);

  @override
  Future<AdminUser?> getAdminById(String id) =>
      remoteDataSource.getAdminById(id);

  @override
  Future<AdminUser> createAdmin({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  }) async {
    final _ = role;
    final cleanEmail = email.trim().toLowerCase();

    // Fast-path: existing Firestore admin for this email.
    try {
      final existingByEmail = await remoteDataSource.getAdminByEmail(cleanEmail);
      if (existingByEmail != null) {
        throw Exception('An Admin account already exists for this email.');
      }
    } on FirebaseException {
      // Scoped list may deny email query; Auth + UID checks still apply.
    }

    String uid;
    try {
      final provisioned = await _provisionAuthUserFn(
        cleanEmail,
        password: password,
      );
      if (provisioned == null || provisioned.trim().isEmpty) {
        throw Exception('Could not create the Firebase Auth user for this admin.');
      }
      uid = provisioned.trim();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Auth exists; do not sign in. Classify via Firestore only.
        AdminUser? existing;
        try {
          existing = await remoteDataSource.getAdminByEmail(cleanEmail);
        } catch (_) {
          existing = null;
        }
        if (existing != null) {
          throw Exception('An Admin account already exists for this email.');
        }
        throw Exception(
          'A Firebase Auth account already exists for this email, but no Admin '
          'profile is linked (orphaned Auth user). In Firebase Console → '
          'Authentication → Users, delete "$cleanEmail", then create the Admin again.',
        );
      }
      throw Exception(AdminAuthEmailClient.publicCreateError(e));
    }

    final existingById = await remoteDataSource.getAdminById(uid);
    if (existingById != null) {
      throw Exception('An Admin account already exists for this email.');
    }

    try {
      return await remoteDataSource.createAdmin(
        id: uid,
        name: name,
        email: cleanEmail,
        phone: phone,
        password: password,
        createdBy: createdBy,
        role: AdminRole.admin,
      );
    } catch (e) {
      // Auth user already exists — do not roll back Auth. Surface recovery path.
      throw Exception(
        'Firebase Auth user was created, but the Admin profile could not be '
        'saved ($e). Stay signed in as Super Admin and try again, or if the '
        'email shows as orphaned, delete it under Authentication → Users first.',
      );
    }
  }

  @override
  Future<void> updateAdmin(AdminUser admin) =>
      remoteDataSource.updateAdmin(admin);

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) =>
      remoteDataSource.toggleAdminActive(adminId, isActive);

  @override
  Future<void> deleteAdmin(String adminId, {String? email}) async {
    final cleanUid = adminId.trim();
    if (cleanUid.isEmpty) {
      throw Exception('Admin ID cannot be empty.');
    }

    // 1. Delete from Firebase Authentication via the Edge Function
    try {
      final authResult = await emailService.deleteAuthAdmin(
        uid: cleanUid,
        email: email,
      );
      if (!authResult.success) {
        AppLogger.warning(
          'Firebase Auth deletion returned error for $cleanUid: ${authResult.userMessage}',
          tag: 'AdminRepository',
        );
        throw Exception(
          'Could not delete admin from Firebase Authentication: ${authResult.userMessage}. '
          'Firestore admin profile was not deleted to prevent orphaned accounts.',
        );
      }
    } catch (e) {
      if (e.toString().contains('Firebase Authentication:')) {
        rethrow;
      }
      AppLogger.warning(
        'Unexpected error calling Auth deletion for $cleanUid: $e',
        tag: 'AdminRepository',
      );
      throw Exception(
        'Could not delete admin from Firebase Authentication: $e. '
        'Firestore admin profile was not deleted to prevent orphaned accounts.',
      );
    }

    // 2. Delete from Firestore
    await remoteDataSource.deleteAdmin(cleanUid);
  }

  @override
  Future<SendCredentialsResult> sendCredentials({
    required AdminUser admin,
    required String password,
    required String senderEmail,
    required String senderPassword,
    required String idempotencyKey,
    void Function(String phase)? onProgress,
  }) {
    return emailService.sendAdminWelcomeEmail(
      admin: admin,
      password: password,
      senderEmail: senderEmail,
      senderPassword: senderPassword,
      idempotencyKey: idempotencyKey,
      onProgress: onProgress,
    );
  }
}
