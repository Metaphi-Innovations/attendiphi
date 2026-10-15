import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/admin_user.dart';
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

  /// Deletes Auth user (by [authUserId] and/or [email]) then the `admins` row
  /// identified by [adminId] (may differ from Auth UUID for legacy rows).
  Future<void> deleteAdmin(String adminId, {String? email, String? authUserId});
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
  });

  final AdminRemoteDataSource remoteDataSource;
  final EmailCredentialsService emailService;

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
    String currentAuthUid = '';
    try {
      currentAuthUid = Supabase.instance.client.auth.currentUser?.id ?? '';
    } catch (_) {}
    final creatorUid = (createdBy != null && createdBy.trim().isNotEmpty)
        ? createdBy.trim()
        : currentAuthUid;

    AdminUser? existingByEmail;
    try {
      existingByEmail = await remoteDataSource.getAdminByEmail(cleanEmail);
    } catch (_) {
      // Scoped access may deny the email lookup; the insert enforces uniqueness.
    }

    if (existingByEmail != null) {
      throw Exception('An Admin account already exists for this email.');
    }

    final created = await remoteDataSource.createAdmin(
      id: const Uuid().v4(),
      name: name,
      email: cleanEmail,
      phone: phone,
      password: password,
      createdBy: creatorUid,
      role: AdminRole.admin,
    );

    // Create matching Supabase Auth user so credentials in the welcome email work.
    final provision = await emailService.provisionAuthAdmin(
      email: cleanEmail,
      password: password,
      adminId: created.id,
    );
    if (!provision.success) {
      AppLogger.warning(
        'Auth provision failed for $cleanEmail: ${provision.userMessage}',
        tag: 'AdminRepository',
      );
      throw Exception(
        'Admin profile was created, but Auth login could not be set up: '
        '${provision.userMessage}',
      );
    }

    return created.copyWith(
      uid: provision.authUserId.isNotEmpty ? provision.authUserId : created.uid,
    );
  }

  @override
  Future<void> updateAdmin(AdminUser admin) =>
      remoteDataSource.updateAdmin(admin);

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) =>
      remoteDataSource.toggleAdminActive(adminId, isActive);

  @override
  Future<void> deleteAdmin(
    String adminId, {
    String? email,
    String? authUserId,
  }) async {
    final profileId = adminId.trim();
    if (profileId.isEmpty) {
      throw Exception('Admin ID cannot be empty.');
    }

    // Prefer Supabase Auth UUID; fall back to email resolution in the Edge Function.
    final authId = (authUserId ?? '').trim();

    // 1. Delete from Supabase Authentication via the Edge Function.
    try {
      final authResult = await emailService.deleteAuthAdmin(
        uid: authId.isNotEmpty ? authId : profileId,
        email: email,
      );
      if (!authResult.success) {
        AppLogger.warning(
          'Supabase Auth deletion returned error for $profileId: ${authResult.userMessage}',
          tag: 'AdminRepository',
        );
        throw Exception(
          'Could not delete admin from Supabase Authentication: ${authResult.userMessage}. '
          'Admin profile was not deleted to prevent orphaned accounts.',
        );
      }
    } catch (e) {
      if (e.toString().contains('Supabase Authentication:')) {
        rethrow;
      }
      AppLogger.warning(
        'Unexpected error calling Auth deletion for $profileId: $e',
        tag: 'AdminRepository',
      );
      throw Exception(
        'Could not delete admin from Supabase Authentication: $e. '
        'Admin profile was not deleted to prevent orphaned accounts.',
      );
    }

    // 2. Delete the admin row from Postgres (profile id, not Auth UUID).
    await remoteDataSource.deleteAdmin(profileId);
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
