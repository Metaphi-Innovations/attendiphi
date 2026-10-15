import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../domain/entities/admin_user.dart';
import 'admin_remote_data_source.dart';
import 'supabase_admin_mapper.dart';

/// Supabase Postgres implementation of [AdminRemoteDataSource].
///
/// Requires an authenticated Supabase session for most operations (RLS).
class SupabaseAdminRemoteDataSource implements AdminRemoteDataSource {
  SupabaseAdminRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  static const _uuid = Uuid();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw const ServerException(
        userMessage: 'Data service is not ready. Please restart the app.',
        technicalMessage: 'Supabase not initialized (admins)',
      );
    }
    return Supabase.instance.client;
  }

  @override
  Stream<List<AdminUser>> watchAdmins({String? createdBy}) {
    final creator = createdBy?.trim();
    return resilientPollStream(
      fetch: () => getAdmins(
        createdBy: (creator == null || creator.isEmpty) ? null : creator,
      ),
      interval: const Duration(seconds: 45),
      tag: 'SupabaseAdminRemoteDataSource',
    );
  }

  @override
  Future<List<AdminUser>> getAdmins({String? createdBy}) async {
    var query = _client.from('admins').select(SupabaseAdminMapper.listSelect);
    final creator = createdBy?.trim() ?? '';
    if (creator.isNotEmpty) {
      query = query.eq('created_by', creator);
    }
    final rows = await query.order('name');
    return rows
        .map((r) => SupabaseAdminMapper.fromRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<AdminUser?> getAdminById(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final row = await _client
        .from('admins')
        .select(SupabaseAdminMapper.listSelect)
        .eq('id', trimmed)
        .maybeSingle();
    if (row == null) return null;
    return SupabaseAdminMapper.fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<AdminUser?> getAdminByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;
    final row = await _client
        .from('admins')
        .select(SupabaseAdminMapper.listSelect)
        .eq('email', cleanEmail)
        .maybeSingle();
    if (row == null) return null;
    return SupabaseAdminMapper.fromRow(Map<String, dynamic>.from(row));
  }

  /// Looks up admin by Supabase Auth user id (`admins.auth_user_id`).
  Future<AdminUser?> getAdminByAuthUserId(String authUserId) async {
    final id = authUserId.trim();
    if (id.isEmpty) return null;
    final row = await _client
        .from('admins')
        .select(SupabaseAdminMapper.listSelect)
        .eq('auth_user_id', id)
        .maybeSingle();
    if (row == null) return null;
    return SupabaseAdminMapper.fromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<AdminUser> createAdmin({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  }) async {
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final cleanEmail = email.trim().toLowerCase();
    final existing = await getAdminByEmail(cleanEmail);
    if (existing != null) {
      throw Exception('An Admin account already exists for this email.');
    }

    // Prefer caller-provided id (Auth uid when provisioned); else new text id.
    final adminId = id.trim().isNotEmpty ? id.trim() : _uuid.v4();
    final admin = AdminUser(
      id: adminId,
      uid: adminId,
      name: name.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      role: role,
      mustResetPassword: true,
      isActive: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await _client.from('admins').insert(SupabaseAdminMapper.toInsert(admin));
    AppLogger.info(
      'Admin created (Supabase): $cleanEmail ($adminId). '
      'Create matching Auth user in Dashboard if not already provisioned.',
      tag: 'SupabaseAdminRemoteDataSource',
    );
    return admin;
  }

  @override
  Future<void> updateAdmin(AdminUser admin) async {
    await _client
        .from('admins')
        .update(SupabaseAdminMapper.toUpdate(admin))
        .eq('id', admin.id);
  }

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) async {
    await _client
        .from('admins')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', adminId);
  }

  @override
  Future<void> deleteAdmin(String adminId) async {
    await _client.from('admins').delete().eq('id', adminId);
  }

  /// Links `admins.auth_user_id` after a successful Supabase Auth sign-in.
  Future<void> linkAuthUserId({
    required String adminId,
    required String authUserId,
  }) async {
    await _client
        .from('admins')
        .update({
          'auth_user_id': authUserId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', adminId);
  }
}
