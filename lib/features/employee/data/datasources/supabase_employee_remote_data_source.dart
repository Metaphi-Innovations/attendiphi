import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/realtime_list_patch.dart';
import '../../../../core/supabase/realtime_snapshot_equals.dart';
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

  /// Active members with SFace templates for public Face check-in.
  Future<List<Employee>> _fetchFaceVerificationCandidates() async {
    final rows = await _client
        .from('public_face_candidates')
        .select(
          'member_id,name,phone,is_active,model,model_version,embedding,raw,updated_at',
        )
        .order('name');
    final list =
        rows
            .map(
              (r) => SupabaseEmployeeMapper.fromFaceCandidateRow(
                Map<String, dynamic>.from(r),
              ),
            )
            .where((e) => e.hasSfaceTemplates)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return list;
  }

  Future<Employee?> _attachFaceTemplates(Employee member) async {
    try {
      final row = await _client
          .from('face_templates')
          .select('member_id,model,model_version,embedding,raw')
          .eq('member_id', member.id)
          .maybeSingle();
      if (row == null) return member;
      return SupabaseEmployeeMapper.withFaceTemplates(
        member,
        Map<String, dynamic>.from(row),
      );
    } on PostgrestException catch (e, st) {
      AppLogger.warning(
        'Supabase attachFaceTemplates failed: ${e.message}\n$st',
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
      return member;
    }
  }

  @override
  Stream<List<Employee>> streamEmployees() {
    return supabaseRealtimeOrPollStream<List<Employee>>(
      client: _client,
      table: 'members',
      fetch: () => _fetchMembers(activeOnly: false),
      applyRealtimeEvent: (current, payload) {
        return patchRealtimeListById<Employee>(
          current: current,
          payload: payload,
          idOf: (e) => e.id,
          fromRow: (row) {
            try {
              return SupabaseEmployeeMapper.fromRow(row);
            } catch (_) {
              return null;
            }
          },
        );
      },
      // Slow backup only; Realtime + resubscribe/tab-visible are primary.
      reconcileInterval: const Duration(minutes: 5),
      isUnchanged: employeesSnapshotUnchanged,
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
      reconcileInterval: const Duration(minutes: 5),
      isUnchanged: employeesSnapshotUnchanged,
      tag: 'SupabasePublicMembersStream',
    );
  }

  @override
  Stream<List<Employee>> streamFaceVerificationCandidates() {
    return supabaseRealtimeOrPollStream<List<Employee>>(
      client: _client,
      table: 'face_templates',
      fetch: _fetchFaceVerificationCandidates,
      reconcileInterval: const Duration(minutes: 5),
      isUnchanged: faceCandidatesSnapshotUnchanged,
      tag: 'SupabaseFaceVerificationCandidates',
    );
  }

  String _normalizePhone(String phone) {
    final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
    return (cleanPhone.startsWith('91') && cleanPhone.length == 12)
        ? cleanPhone.substring(2)
        : cleanPhone;
  }

  /// Rejects when another **active** member already uses [phoneDigits].
  Future<void> _assertActivePhoneAvailable(
    String phoneDigits, {
    String? excludingMemberId,
    required bool willBeActive,
  }) async {
    if (!willBeActive || phoneDigits.isEmpty) return;

    var query = _client
        .from('members')
        .select('id,name')
        .eq('is_active', true)
        .eq('phone', phoneDigits);
    final exclude = excludingMemberId?.trim() ?? '';
    if (exclude.isNotEmpty) {
      query = query.neq('id', exclude);
    }
    final rows = await query.limit(1);
    if (rows.isEmpty) return;

    final otherName = rows.first['name']?.toString().trim() ?? '';
    final who = otherName.isEmpty ? 'Another active member' : otherName;
    throw ServerException(
      userMessage:
          '$who already uses this phone number. '
          'Use a different phone, or deactivate that member first.',
      technicalMessage:
          'Duplicate active member phone: $phoneDigits'
          '${exclude.isEmpty ? '' : ' (excluding $exclude)'}',
    );
  }

  ServerException _mapMemberWriteError(
    PostgrestException e,
    StackTrace st, {
    required String action,
  }) {
    final isUnique =
        e.code == '23505' ||
        e.message.toLowerCase().contains('members_active_phone_unique');
    if (isUnique) {
      return ServerException(
        userMessage:
            'Another active member already uses this phone number. '
            'Use a different phone, or deactivate that member first.',
        technicalMessage: 'Failed to $action employee (unique phone): ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
    return ServerException(
      technicalMessage: 'Failed to $action employee: ${e.message}',
      originalError: e,
      stackTrace: st,
    );
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

      await _assertActivePhoneAvailable(
        phoneDigits,
        willBeActive: isActive,
      );

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
      throw _mapMemberWriteError(
        e,
        st,
        action: 'add',
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

      if (phoneDigits.length == 10) {
        await _assertActivePhoneAvailable(
          phoneDigits,
          excludingMemberId: id,
          willBeActive: isActive,
        );
      }

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
      throw _mapMemberWriteError(e, st, action: 'update');
    }
  }

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) async {
    try {
      if (isActive) {
        final row = await _client
            .from('members')
            .select('phone')
            .eq('id', id)
            .maybeSingle();
        final phoneDigits = _normalizePhone(row?['phone']?.toString() ?? '');
        if (phoneDigits.length == 10) {
          await _assertActivePhoneAvailable(
            phoneDigits,
            excludingMemberId: id,
            willBeActive: true,
          );
        }
      }
      await _client
          .from('members')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id);
    } on AppException {
      rethrow;
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
      final member = SupabaseEmployeeMapper.fromRow(
        Map<String, dynamic>.from(row),
      );
      return await _attachFaceTemplates(member);
    } on PostgrestException catch (e, st) {
      AppLogger.warning(
        'Supabase getEmployee failed: ${e.message}\n$st',
        tag: 'SupabaseEmployeeRemoteDataSource',
      );
      return null;
    }
  }
}
