import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/supabase_realtime_or_poll_stream.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/employee.dart';
import 'employee_remote_data_source.dart';
import 'supabase_employee_mapper.dart';

/// Supabase Postgres implementation of [EmployeeRemoteDataSource].
///
/// Phase 4: reads/writes `public.members` (+ optional `face_templates`).
/// Admin mutations require Supabase Auth (Phase 5); anon can only read active
/// members per RLS.
class SupabaseEmployeeRemoteDataSource implements EmployeeRemoteDataSource {
  SupabaseEmployeeRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  static const _uuid = Uuid();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw const ServerException(
        userMessage: 'Data service is not ready. Please restart the app.',
        technicalMessage: 'Supabase not initialized (members)',
      );
    }
    return Supabase.instance.client;
  }

  Future<List<Employee>> _fetchMembers({required bool activeOnly}) async {
    var query = _client
        .from('members')
        .select(SupabaseEmployeeMapper.listSelect);
    if (activeOnly) {
      query = query.eq('is_active', true);
    }
    final rows = await query.order('name');
    final list =
        rows
            .map(
              (r) =>
                  SupabaseEmployeeMapper.fromRow(Map<String, dynamic>.from(r)),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return list;
  }

  /// QR typeahead — reads `public.public_members` (id/name/phone only).
  Future<List<Employee>> _fetchPublicMembers() async {
    final rows = await _client
        .from('public_members')
        .select('id,name,phone,is_active')
        .order('name');
    final list =
        rows
            .map(
              (r) =>
                  SupabaseEmployeeMapper.fromRow(Map<String, dynamic>.from(r)),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return list;
  }

  @override
  Stream<List<Employee>> streamEmployees() {
    return supabaseRealtimeOrPollStream<List<Employee>>(
      client: _client,
      table: 'members',
      fetch: () => _fetchMembers(activeOnly: false),
      tag: 'SupabaseEmployeeRemoteDataSource',
    );
  }

  @override
  Stream<List<Employee>> streamPublicMembers() {
    // Realtime is on `members`; refetch projects through public_members view.
    return supabaseRealtimeOrPollStream<List<Employee>>(
      client: _client,
      table: 'members',
      fetch: _fetchPublicMembers,
      filter: const PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'is_active',
        value: true,
      ),
      tag: 'SupabasePublicMembersStream',
    );
  }

  String _normalizePhone(String phone) {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    return (cleanPhone.startsWith('91') && cleanPhone.length == 12)
        ? cleanPhone.substring(2)
        : cleanPhone;
  }

  Future<void> _upsertFaceTemplates({
    required String memberId,
    required String name,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    String? faceModel,
    String? faceModelVersion,
  }) async {
    if (faceEmbedding == null &&
        (faceTemplates == null || faceTemplates.isEmpty)) {
      return;
    }
    final embedding =
        faceEmbedding ??
        (faceTemplates != null && faceTemplates.isNotEmpty
            ? faceTemplates.first
            : null);
    if (embedding == null) return;

    await _client.from('face_templates').upsert({
      'id': memberId,
      'member_id': memberId,
      'name': name,
      'model': faceModel,
      'model_version': faceModelVersion,
      'embedding': embedding,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (faceTemplates != null) 'raw': {'faceTemplates': faceTemplates},
    });
  }

  @override
  Future<void> addEmployee(
    String name, {
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
    String? photoUrl,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    bool faceEnrolled = false,
    String? faceModel,
    String? faceModelVersion,
  }) async {
    try {
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        throw const ServerException(
          userMessage: 'Employee name cannot be empty',
          technicalMessage: 'Validation failed: empty employee name',
        );
      }
      final phoneDigits = _normalizePhone(phone);
      if (phoneDigits.length != 10) {
        throw const ServerException(
          userMessage: 'Please enter a valid 10-digit phone number',
          technicalMessage:
              'Validation failed: empty or invalid employee phone',
        );
      }

      final id = _uuid.v4();
      await _client
          .from('members')
          .insert(
            SupabaseEmployeeMapper.toInsert(
              id: id,
              name: cleanName,
              email: email,
              phone: phoneDigits,
              role: role,
              designation: designation,
              isActive: isActive,
              adminId: adminId,
              photoUrl: photoUrl,
              faceEnrolled: faceEnrolled,
              faceModel: faceModel,
              faceModelVersion: faceModelVersion,
            ),
          );

      await _upsertFaceTemplates(
        memberId: id,
        name: cleanName,
        faceEmbedding: faceEmbedding,
        faceTemplates: faceTemplates,
        faceModel: faceModel,
        faceModelVersion: faceModelVersion,
      );

      AppLogger.info(
        'Employee added (Supabase): $cleanName ($id)',
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      AppLogger.error(
        'Supabase error adding employee: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to add employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> updateEmployee(
    String id,
    String name, {
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
    String? photoUrl,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    bool? faceEnrolled,
    String? faceModel,
    String? faceModelVersion,
  }) async {
    try {
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        throw const ServerException(
          userMessage: 'Employee name cannot be empty',
          technicalMessage: 'Validation failed: empty employee name',
        );
      }
      final phoneDigits = phone.trim().isEmpty
          ? ''
          : Validators.normalizePhone(phone).length >= 10
          ? _normalizePhone(phone)
          : phone.trim();

      await _client
          .from('members')
          .update(
            SupabaseEmployeeMapper.toUpdate(
              name: cleanName,
              email: email,
              phone: phoneDigits,
              role: role,
              designation: designation,
              isActive: isActive,
              adminId: adminId,
              photoUrl: photoUrl,
              faceEnrolled: faceEnrolled,
              faceModel: faceModel,
              faceModelVersion: faceModelVersion,
            ),
          )
          .eq('id', id);

      await _upsertFaceTemplates(
        memberId: id,
        name: cleanName,
        faceEmbedding: faceEmbedding,
        faceTemplates: faceTemplates,
        faceModel: faceModel,
        faceModelVersion: faceModelVersion,
      );

      AppLogger.info(
        'Employee updated (Supabase): $id',
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      AppLogger.error(
        'Supabase error updating employee: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to update employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) async {
    try {
      await _client
          .from('members')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } on PostgrestException catch (e, st) {
      throw ServerException(
        technicalMessage: 'Failed to toggle employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    try {
      await _client.from('members').delete().eq('id', id);
      AppLogger.info(
        'Employee deleted (Supabase): $id',
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
    } on PostgrestException catch (e, st) {
      throw ServerException(
        technicalMessage: 'Failed to delete employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteAllEmployees() async {
    try {
      await _client.from('members').delete().neq('id', '');
    } on PostgrestException catch (e, st) {
      throw ServerException(
        technicalMessage: 'Failed to delete all employees: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<Employee?> getEmployee(String id) async {
    try {
      final row = await _client
          .from('members')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return SupabaseEmployeeMapper.fromRow(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e, st) {
      AppLogger.warning(
        'Supabase getEmployee failed: ${e.message}\n$st',
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
      return null;
    }
  }
}
