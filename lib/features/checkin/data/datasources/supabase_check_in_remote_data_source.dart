import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/realtime_list_patch.dart';
import '../../../../core/supabase/realtime_snapshot_equals.dart';
import '../../../../core/supabase/supabase_realtime_or_poll_stream.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/paginated_check_ins_result.dart';
import '../../domain/session_lock_ids.dart';
import '../mappers/supabase_check_in_mapper.dart';
import 'check_in_remote_data_source.dart';

/// Supabase Postgres implementation of [CheckInRemoteDataSource].
class SupabaseCheckInRemoteDataSource implements CheckInRemoteDataSource {
  SupabaseCheckInRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  static const photoBucket = 'check-in-photos';

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw const ServerException(
        userMessage: 'Data service is not ready. Please restart the app.',
        technicalMessage: 'Supabase not initialized (check_ins)',
      );
    }
    return Supabase.instance.client;
  }

  bool _isUniqueViolation(PostgrestException e) {
    final code = e.code ?? '';
    return code == '23505' ||
        e.message.toLowerCase().contains('duplicate') ||
        e.message.toLowerCase().contains('unique');
  }

  @override
  Future<void> createCheckIn(
    CheckInSubmission submission, {
    bool enforceThursday = true,
    String? sessionDateYmd,
    String? claimDeviceId,
    String? claimMemberId,
    String? sessionToken,
  }) async {
    try {
      final date = SessionLockIds.sessionDateYmd(
        sessionDateStr: sessionDateYmd,
        fallbackTimestamp: submission.timestamp,
      );

      final photo = submission.photoBase64;
      var photoPath = submission.photoPath?.trim();
      if ((photoPath == null || photoPath.isEmpty) &&
          photo != null &&
          photo.trim().isNotEmpty) {
        photoPath = await _uploadCheckInPhoto(
          checkInId: submission.id,
          sessionDateYmd: date,
          photoBase64: photo,
        );
      }

      // When device restriction is ON, SubmitCheckIn passes claimDeviceId.
      // Ensure it lands on the row so the RPC can claim device_session_locks.
      final effectiveDeviceId =
          (claimDeviceId ?? submission.deviceId)?.trim() ?? '';

      final row = SupabaseCheckInMapper.toRow(
        submission.copyWith(
          photoPath: photoPath,
          hasPhoto: photoPath != null && photoPath.isNotEmpty,
          photoBase64: '',
          deviceId: effectiveDeviceId.isEmpty ? submission.deviceId : effectiveDeviceId,
        ),
      );
      row.remove('photo_base64');
      row['session_date'] = date;
      if (photoPath != null && photoPath.isNotEmpty) {
        row['photo_path'] = photoPath;
        row['has_photo'] = true;
      }

      await _client.rpc(
        'submit_public_check_in',
        params: {
          'p_row': row,
          'p_session_date': date,
          'p_claim_member_id': claimMemberId?.trim().isNotEmpty == true
              ? claimMemberId!.trim()
              : null,
          'p_session_token': sessionToken?.trim().isNotEmpty == true
              ? sessionToken!.trim()
              : null,
          'p_enforce_restrictions': enforceThursday,
        },
      );

      AppLogger.info(
        'Check-in recorded (Supabase RPC): ${submission.userName} '
        '(${submission.type.name}) at ${submission.locationName}',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      final msg = '${e.message} ${e.details ?? ''} ${e.hint ?? ''}'
          .toLowerCase();
      if (msg.contains('duplicate_phone')) {
        throw const DuplicateCheckInException(
          userMessage:
              'This phone number has already submitted attendance for today.',
          technicalMessage: 'submit_public_check_in duplicate_phone',
        );
      }
      if (msg.contains('duplicate_member')) {
        throw const DuplicateCheckInException(
          userMessage:
              'This member has already been checked in for this session.',
          technicalMessage: 'submit_public_check_in duplicate_member',
        );
      }
      if (msg.contains('duplicate_device')) {
        throw const DuplicateCheckInException(
          userMessage:
              'This device has already recorded attendance for today. '
              'Use another device, or ask an admin to turn off '
              '"One device = one check-in".',
          technicalMessage: 'submit_public_check_in duplicate_device',
        );
      }
      if (msg.contains('thursday_only')) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'Check-in is available on Thursday only.',
          technicalMessage: 'submit_public_check_in thursday_only',
        );
      }
      if (msg.contains('session_date_mismatch') ||
          msg.contains('invalid_session_token')) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'This check-in QR session is not valid for today.',
          technicalMessage: 'submit_public_check_in session/token',
        );
      }
      if (msg.contains('outside_radius')) {
        throw const CheckInSubmissionFailedException(
          userMessage: 'You appear to be outside the venue. Please move closer and try again.',
          technicalMessage: 'submit_public_check_in outside_radius',
        );
      }
      AppLogger.error(
        'Supabase RPC error recording check-in: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Supabase write error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is AppException) rethrow;
      AppLogger.error(
        'Unexpected error recording check-in: $e',
        error: e,
        stackTrace: st,
        tag: 'SupabaseCheckInRemoteDataSource',
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
      if (CheckInSubmission.isPlaceholderId(submission.id) ||
          submission.type.isNotCheckedIn) {
        throw const ServerException(
          technicalMessage: 'Cannot write placeholder check-in id; materialize with a real UUID first.',
        );
      }
      if (submission.locationId.trim().isEmpty) {
        throw const ServerException(
          technicalMessage: 'Cannot write check-in without locationId.',
        );
      }

      final row = SupabaseCheckInMapper.toRow(submission);
      await _client.from('check_ins').upsert(row);

      AppLogger.info(
        'Check-in updated (Supabase): ${submission.id}',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on PostgrestException catch (e, st) {
      throw ServerException(
        technicalMessage: 'Supabase update error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteCheckIn(String checkInId) async {
    try {
      await _client.from('check_ins').delete().eq('id', checkInId);
    } on PostgrestException catch (e, st) {
      throw ServerException(
        technicalMessage: 'Supabase delete error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteAllCheckIns({String? locationId}) async {
    try {
      var q = _client.from('check_ins').delete();
      if (locationId != null && locationId.isNotEmpty) {
        q = q.eq('location_id', locationId);
      } else {
        q = q.neq('id', '');
      }
      await q;
    } on PostgrestException catch (e, st) {
      throw ServerException(
        technicalMessage: 'Supabase delete all error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  Future<String> _uploadCheckInPhoto({
    required String checkInId,
    required String sessionDateYmd,
    required String photoBase64,
  }) async {
    final decoded = ImageUtils.base64ToBytes(photoBase64);
    if (decoded == null || decoded.isEmpty) {
      throw const CheckInSubmissionFailedException(
        userMessage: 'Photo could not be processed. Please retake your selfie.',
        technicalMessage: 'check-in photo base64 decode failed',
      );
    }
    // Always store JPEG so bucket MIME allow-list never rejects gallery PNGs /
    // webp / octet-stream multipart fallbacks (those return HTTP 400).
    final bytes = ImageUtils.toJpegBytes(decoded);
    if (bytes.isEmpty) {
      throw const CheckInSubmissionFailedException(
        userMessage: 'Photo could not be processed. Please retake your selfie.',
        technicalMessage: 'check-in photo jpeg encode produced empty bytes',
      );
    }
    final path = '$sessionDateYmd/${checkInId.trim()}.jpg';
    try {
      await _client.storage
          .from(photoBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return path;
    } on StorageException catch (e, st) {
      AppLogger.error(
        'Storage upload failed for check-in photo'
        ' (${e.statusCode}: ${e.message})',
        error: e,
        stackTrace: st,
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      throw CheckInSubmissionFailedException(
        userMessage: 'Photo upload failed. Please try again.',
        technicalMessage:
            'storage upload: ${e.statusCode} ${e.message}',
      );
    }
  }

  Future<List<CheckInSubmission>> _fetchCheckIns({
    String? locationId,
    String? sessionDateYmd,
    String? sessionDateFrom,
    String? sessionDateTo,
  }) async {
    // Lean select — never pull photo_base64 on the list stream.
    var query = _client
        .from('check_ins')
        .select(SupabaseCheckInMapper.listSelect);
    if (locationId != null && locationId.isNotEmpty) {
      query = query.eq('location_id', locationId);
    }
    final day = sessionDateYmd?.trim() ?? '';
    if (day.length == 10) {
      query = query.eq('session_date', day);
    } else {
      final from = sessionDateFrom?.trim() ?? '';
      final to = sessionDateTo?.trim() ?? '';
      if (from.length == 10) {
        query = query.gte('session_date', from);
      }
      if (to.length == 10) {
        query = query.lte('session_date', to);
      }
    }
    final rows = await query.order('timestamp', ascending: false);
    return rows
        .map((r) => SupabaseCheckInMapper.fromRow(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<String?> resolveCheckInPhotoUrl(CheckInSubmission submission) async {
    final path = submission.photoPath?.trim() ?? '';
    if (path.isNotEmpty) {
      try {
        return await _client.storage
            .from(photoBucket)
            .createSignedUrl(path, 60 * 30);
      } catch (e, st) {
        AppLogger.warning(
          'Signed URL failed for $path: $e\n$st',
          tag: 'SupabaseCheckInRemoteDataSource',
        );
      }
    }
    // Legacy rows: fetch base64 once on demand.
    if (!submission.hasPhoto &&
        (submission.photoBase64 == null ||
            submission.photoBase64!.trim().isEmpty)) {
      return null;
    }
    try {
      final row = await _client
          .from('check_ins')
          .select(SupabaseCheckInMapper.photoSelect)
          .eq('id', submission.id)
          .maybeSingle();
      if (row == null) return null;
      final storedPath = row['photo_path']?.toString().trim() ?? '';
      if (storedPath.isNotEmpty) {
        return await _client.storage
            .from(photoBucket)
            .createSignedUrl(storedPath, 60 * 30);
      }
      final b64 = row['photo_base64']?.toString().trim() ?? '';
      if (b64.isEmpty) return null;
      return 'data:image/jpeg;base64,$b64';
    } catch (e, st) {
      AppLogger.warning(
        'Photo resolve failed for ${submission.id}: $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      return null;
    }
  }

  Future<Set<String>> _fetchSessionMemberIds(String sessionDateYmd) async {
    final row = await _client
        .from('session_attendance')
        .select('checked_in_member_ids')
        .eq('session_date', sessionDateYmd)
        .maybeSingle();
    if (row == null) return const <String>{};
    final raw = row['checked_in_member_ids'];
    if (raw is! List) return const <String>{};
    return {
      for (final mid in raw)
        if (mid != null && mid.toString().trim().isNotEmpty)
          mid.toString().trim(),
    };
  }

  @override
  Stream<List<CheckInSubmission>> streamCheckIns({
    String? locationId,
    String? sessionDateYmd,
    String? sessionDateFrom,
    String? sessionDateTo,
  }) {
    final loc = locationId?.trim();
    final day = sessionDateYmd?.trim();
    return supabaseRealtimeOrPollStream<List<CheckInSubmission>>(
      client: _client,
      table: 'check_ins',
      fetch: () => _fetchCheckIns(
        locationId: locationId,
        sessionDateYmd: sessionDateYmd,
        sessionDateFrom: sessionDateFrom,
        sessionDateTo: sessionDateTo,
      ),
      filter: (loc != null && loc.isNotEmpty)
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'location_id',
              value: loc,
            )
          : (day != null && day.length == 10)
          ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'session_date',
              value: day,
            )
          : null,
      // Patch local list from WS payload — no REST on each new check-in.
      applyRealtimeEvent: (current, payload) {
        return patchRealtimeListById<CheckInSubmission>(
          current: current,
          payload: payload,
          idOf: (c) => c.id,
          fromRow: (row) {
            try {
              return SupabaseCheckInMapper.fromRow(row);
            } catch (_) {
              return null;
            }
          },
          include: (loc != null && loc.isNotEmpty)
              ? (c) => c.locationId.trim() == loc
              : null,
        );
      },
      // Slow backup only; Realtime + resubscribe/tab-visible are primary.
      reconcileInterval: const Duration(minutes: 5),
      isUnchanged: checkInsSnapshotUnchanged,
      tag: 'SupabaseCheckInRemoteDataSource',
    );
  }

  @override
  Stream<Set<String>> streamSessionCheckedInMemberIds(String sessionDateYmd) {
    final date = sessionDateYmd.trim();
    if (date.length != 10) {
      return Stream.value(const <String>{});
    }
    return supabaseRealtimeOrPollStream<Set<String>>(
      client: _client,
      table: 'session_attendance',
      fetch: () => _fetchSessionMemberIds(date),
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'session_date',
        value: date,
      ),
      reconcileInterval: const Duration(minutes: 5),
      isUnchanged: stringSetSnapshotUnchanged,
      tag: 'SupabaseSessionAttendanceStream',
    );
  }

  /// Offset cursor for Supabase range pagination (int).
  static int _offsetFromCursor(Object? startAfter) {
    if (startAfter is int) return startAfter;
    if (startAfter is String) return int.tryParse(startAfter) ?? 0;
    return 0;
  }

  @override
  Future<PaginatedCheckInsResult> getPaginatedCheckIns({
    int limit = AppConstants.dashboardPageSize,
    Object? startAfter,
    String? locationId,
  }) async {
    try {
      final offset = _offsetFromCursor(startAfter);
      var query = _client
          .from('check_ins')
          .select(SupabaseCheckInMapper.listSelect);

      if (locationId != null && locationId.isNotEmpty) {
        query = query.eq('location_id', locationId);
      }

      // range is inclusive; fetch one extra to detect hasMore.
      final rows = await query
          .order('timestamp', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + limit);
      final hasMore = rows.length > limit;
      final page = hasMore ? rows.take(limit).toList() : rows;
      final items = page
          .map(
            (r) => SupabaseCheckInMapper.fromRow(Map<String, dynamic>.from(r)),
          )
          .toList();

      return PaginatedCheckInsResult(
        items: items,
        lastDocument: items.isEmpty ? null : offset + items.length,
        hasMore: hasMore,
      );
    } on PostgrestException catch (e, st) {
      AppLogger.error(
        'Supabase paginated check-ins error: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Supabase read error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  String _sessionYmd(DateTime sessionDate) {
    final m = sessionDate.month.toString().padLeft(2, '0');
    final d = sessionDate.day.toString().padLeft(2, '0');
    return '${sessionDate.year}-$m-$d';
  }

  bool _isSameSessionDate(dynamic tsRaw, DateTime sessionDate) {
    final parsed = DateTime.tryParse(tsRaw?.toString() ?? '');
    if (parsed == null) return false;
    final local = parsed.toLocal();
    return local.year == sessionDate.year &&
        local.month == sessionDate.month &&
        local.day == sessionDate.day;
  }

  /// Prefer calendar [session_date] column; fall back to local timestamp day.
  bool _rowMatchesSession(Map<String, dynamic> map, DateTime sessionDate) {
    final ymd = _sessionYmd(sessionDate);
    final raw = map['session_date']?.toString().trim() ?? '';
    if (raw.length >= 10 && raw.substring(0, 10) == ymd) return true;
    return _isSameSessionDate(map['timestamp'], sessionDate);
  }

  @override
  Future<CheckInSubmission?> getIdentitySubmission(
    String phone,
    DateTime sessionDate,
  ) async {
    try {
      final normalizedPhone = Validators.normalizePhone(phone);
      final formattedPhone = Validators.formatPhoneWithCountryCode(phone);
      final phoneVariants = <String>{
        formattedPhone,
        normalizedPhone,
        if (normalizedPhone.isNotEmpty) '91$normalizedPhone',
        if (phone.trim().isNotEmpty) phone.trim(),
      }.toList();

      final rows = await _client
          .from('check_ins')
          .select(SupabaseCheckInMapper.listSelect)
          .inFilter('user_phone', phoneVariants);

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        if (_rowMatchesSession(map, sessionDate)) {
          return SupabaseCheckInMapper.fromRow(map);
        }
      }
      return null;
    } catch (e, st) {
      AppLogger.warning(
        'Error finding identity submission (Supabase): $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
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
  Future<CheckInSubmission?> getDeviceSubmission(
    String deviceId,
    DateTime sessionDate,
  ) async {
    try {
      final id = deviceId.trim();
      if (id.isEmpty) return null;
      final rows = await _client
          .from('check_ins')
          .select(SupabaseCheckInMapper.listSelect)
          .eq('device_id', id);

      for (final row in rows) {
        final map = Map<String, dynamic>.from(row);
        if (_rowMatchesSession(map, sessionDate)) {
          return SupabaseCheckInMapper.fromRow(map);
        }
      }
      return null;
    } catch (e, st) {
      AppLogger.warning(
        'Error finding device submission (Supabase): $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      return null;
    }
  }

  @override
  Future<void> claimDeviceSessionLock({
    required String deviceId,
    required String sessionDateYmd,
  }) async {
    try {
      await _client.from('device_session_locks').insert({
        'id': SessionLockIds.deviceLockId(deviceId, sessionDateYmd),
        'device_id': deviceId.trim(),
        'session_date': sessionDateYmd,
      });
    } on PostgrestException catch (e, st) {
      if (_isUniqueViolation(e)) {
        throw const DuplicateCheckInException(
          userMessage: 'This device has already recorded attendance for today.',
          technicalMessage: 'device_session_locks already-exists',
        );
      }
      throw ServerException(
        technicalMessage: 'Device lock claim failed: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<bool> isDeviceSessionLocked({
    required String deviceId,
    required String sessionDateYmd,
  }) async {
    try {
      final row = await _client
          .from('device_session_locks')
          .select('id')
          .eq('id', SessionLockIds.deviceLockId(deviceId, sessionDateYmd))
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }
}
