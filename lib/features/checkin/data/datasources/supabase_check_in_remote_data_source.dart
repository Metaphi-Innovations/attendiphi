import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/config/supabase_app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/realtime_list_patch.dart';
import '../../../../core/supabase/realtime_snapshot_equals.dart';
import '../../../../core/supabase/supabase_realtime_or_poll_stream.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';
import '../../domain/entities/paginated_check_ins_result.dart';
import '../../domain/entities/public_device_session_attendance.dart';
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

      // Device lock claim: only [claimDeviceId] (set when device restriction is
      // ON). Still keep [submission.deviceId] on the row for audit when the
      // Super Admin has standee mode (device restriction OFF) — the RPC skips
      // device_session_locks when the flag is false.
      final claim = claimDeviceId?.trim() ?? '';
      final auditDevice = submission.deviceId?.trim() ?? '';
      final rowDeviceId = claim.isNotEmpty
          ? claim
          : (auditDevice.isNotEmpty ? auditDevice : null);

      final row = SupabaseCheckInMapper.toRow(
        submission.copyWith(
          photoPath: photoPath,
          hasPhoto: photoPath != null && photoPath.isNotEmpty,
          photoBase64: '',
          deviceId: rowDeviceId,
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
              'This phone number has already submitted the same type of '
              'check-in for today.',
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
              'Attendance for this session was already submitted on this phone.',
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

      // Lean row: mapper never writes photo_base64 into Postgres.
      final row = SupabaseCheckInMapper.toRow(submission);
      await _client.from('check_ins').upsert(row);

      // QR typeahead projection (session_attendance) is eventually consistent.
      // Do not block admin Verify/Edit on the extra fetch+upsert round trip.
      final memberId = submission.memberId?.trim() ?? '';
      if (memberId.isNotEmpty &&
          (submission.type.isMember ||
              submission.type.isSubstitute ||
              submission.type.isAbsent)) {
        final date = SessionLockIds.sessionDateYmd(
          fallbackTimestamp: submission.timestamp,
        );
        unawaited(
          _mergeSessionAttendanceMember(
            sessionDateYmd: date,
            memberId: memberId,
          ),
        );
      }

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
      final id = checkInId.trim();
      if (id.isEmpty) return;

      // Capture session date before delete so QR projection can be rebuilt.
      final existing = await _client
          .from('check_ins')
          .select('session_date,timestamp')
          .eq('id', id)
          .maybeSingle();

      await _client.from('check_ins').delete().eq('id', id);

      final sessionDate = existing?['session_date']?.toString().trim() ?? '';
      String? date;
      if (sessionDate.length >= 10) {
        date = sessionDate.substring(0, 10);
      } else {
        final parsed = existing?['timestamp'] != null
            ? DateTime.tryParse(existing!['timestamp'].toString())
            : null;
        if (parsed != null) {
          date = SessionLockIds.sessionDateYmd(fallbackTimestamp: parsed);
        }
      }
      if (date != null && date.length == 10) {
        await _rebuildSessionAttendanceForDate(date);
      }
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
      // Raw binary POST keeps Content-Type: image/jpeg. Flutter web's
      // storage.uploadBinary multipart path often arrives as
      // application/octet-stream → bucket MIME allow-list → HTTP 400.
      await _uploadCheckInPhotoRaw(path: path, bytes: bytes);
      return path;
    } on CheckInSubmissionFailedException {
      rethrow;
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
    } catch (e, st) {
      AppLogger.error(
        'Storage upload failed for check-in photo: $e',
        error: e,
        stackTrace: st,
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      throw CheckInSubmissionFailedException(
        userMessage: 'Photo upload failed. Please try again.',
        technicalMessage: 'storage upload: $e',
      );
    }
  }

  /// Uploads JPEG bytes with an explicit Content-Type header (not multipart).
  ///
  /// Always authenticates as the publishable anon key — not the current
  /// admin session. QR check-in is a public flow; Storage INSERT policies are
  /// granted to `anon`. Using a logged-in Super Admin JWT (`authenticated`)
  /// caused HTTP 400 when testing Substitute photos from the standee tab.
  Future<void> _uploadCheckInPhotoRaw({
    required String path,
    required Uint8List bytes,
  }) async {
    if (!SupabaseBootstrap.isInitialized && _clientOverride == null) {
      throw const ServerException(
        userMessage: 'Data service is not ready. Please restart the app.',
        technicalMessage: 'Supabase not initialized (photo upload)',
      );
    }
    final baseUrl = SupabaseAppConfig.url.replaceAll(RegExp(r'/+$'), '');
    final anonKey = SupabaseAppConfig.anonKey;
    final uri = Uri.parse('$baseUrl/storage/v1/object/$photoBucket/$path');

    // Use Request + bodyBytes so Content-Type stays exactly image/jpeg
    // (no charset) on Flutter web.
    final request = http.Request('POST', uri)
      ..headers.addAll(<String, String>{
        'Authorization': 'Bearer $anonKey',
        'apikey': anonKey,
        'Content-Type': 'image/jpeg',
        'x-upsert': 'true',
      })
      ..bodyBytes = bytes;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.error(
        'Storage raw upload failed (${response.statusCode}): '
        '${response.body}',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      throw CheckInSubmissionFailedException(
        userMessage: 'Photo upload failed. Please try again.',
        technicalMessage:
            'storage raw upload: ${response.statusCode} ${response.body}',
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

  /// Adds [memberId] to the public session attendance projection (idempotent).
  Future<void> _mergeSessionAttendanceMember({
    required String sessionDateYmd,
    required String memberId,
  }) async {
    final date = sessionDateYmd.trim();
    final mid = memberId.trim();
    if (date.length != 10 || mid.isEmpty) return;
    try {
      final existing = await _fetchSessionMemberIds(date);
      if (existing.contains(mid)) return;
      final next = [...existing, mid];
      await _client.from('session_attendance').upsert({
        'id': date,
        'session_date': date,
        'checked_in_member_ids': next,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_date');
    } catch (e, st) {
      AppLogger.warning(
        'session_attendance merge failed for $date/$mid: $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
    }
  }

  /// Rebuilds QR projection for one day from remaining `check_ins` rows.
  Future<void> _rebuildSessionAttendanceForDate(String sessionDateYmd) async {
    final date = sessionDateYmd.trim();
    if (date.length != 10) return;
    try {
      final rows = await _client
          .from('check_ins')
          .select('member_id')
          .eq('session_date', date);
      final ids = <String>{
        for (final row in rows)
          if ((row['member_id']?.toString().trim() ?? '').isNotEmpty)
            row['member_id'].toString().trim(),
      };
      await _client.from('session_attendance').upsert({
        'id': date,
        'session_date': date,
        'checked_in_member_ids': ids.toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'session_date');
    } catch (e, st) {
      AppLogger.warning(
        'session_attendance rebuild failed for $date: $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
    }
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
    DateTime sessionDate, {
    CheckInType? type,
  }) async {
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
        if (!_rowMatchesSession(map, sessionDate)) continue;
        final submission = SupabaseCheckInMapper.fromRow(map);
        if (type != null && submission.type != type) continue;
        return submission;
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
  Future<bool> hasIdentityCheckedIn(
    String phone,
    DateTime sessionDate, {
    CheckInType? type,
  }) async {
    final submission = await getIdentitySubmission(
      phone,
      sessionDate,
      type: type,
    );
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
          userMessage:
              'Attendance for this session was already submitted on this phone.',
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

  @override
  Future<PublicDeviceSessionAttendance?> getPublicDeviceSessionAttendance({
    required String deviceId,
    required String sessionDateYmd,
  }) async {
    try {
      final id = deviceId.trim();
      final date = sessionDateYmd.trim();
      if (id.isEmpty || date.isEmpty) {
        return const PublicDeviceSessionAttendance(locked: false);
      }

      final raw = await _client.rpc(
        'get_public_device_session_attendance',
        params: {
          'p_device_id': id,
          'p_session_date': date,
        },
      );

      if (raw == null) {
        return const PublicDeviceSessionAttendance(locked: false);
      }

      final Map<String, dynamic> map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      } else {
        return const PublicDeviceSessionAttendance(locked: false);
      }

      final locked = map['locked'] == true;
      if (!locked) {
        return const PublicDeviceSessionAttendance(locked: false);
      }

      final checkInId =
          map['id']?.toString().trim().isNotEmpty == true
          ? map['id']!.toString().trim()
          : (map['check_in_id']?.toString().trim().isNotEmpty == true
                ? map['check_in_id']!.toString().trim()
                : null);

      CheckInSubmission? submission;
      final userName = map['user_name']?.toString().trim() ?? '';
      final hasRowPayload =
          checkInId != null &&
          (userName.isNotEmpty ||
              map['location_id'] != null ||
              map['user_phone'] != null ||
              map['type'] != null);
      if (hasRowPayload) {
        final row = Map<String, dynamic>.from(map);
        row['id'] = checkInId;
        submission = SupabaseCheckInMapper.fromRow(row);
      }

      return PublicDeviceSessionAttendance(
        locked: true,
        submission: submission,
        checkInId: checkInId,
      );
    } catch (e, st) {
      AppLogger.warning(
        'get_public_device_session_attendance failed: $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      return null;
    }
  }

  @override
  Future<CheckInSubmission?> getPublicCheckInSummary(String checkInId) async {
    try {
      final id = checkInId.trim();
      if (id.isEmpty) return null;

      final raw = await _client.rpc(
        'get_public_check_in_summary',
        params: {'p_check_in_id': id},
      );
      if (raw == null) return null;

      final Map<String, dynamic> map;
      if (raw is Map<String, dynamic>) {
        map = raw;
      } else if (raw is Map) {
        map = Map<String, dynamic>.from(raw);
      } else {
        return null;
      }

      final resolvedId =
          map['id']?.toString().trim().isNotEmpty == true
          ? map['id']!.toString().trim()
          : (map['check_in_id']?.toString().trim().isNotEmpty == true
                ? map['check_in_id']!.toString().trim()
                : id);
      final row = Map<String, dynamic>.from(map);
      row['id'] = resolvedId;
      return SupabaseCheckInMapper.fromRow(row);
    } catch (e, st) {
      AppLogger.warning(
        'get_public_check_in_summary failed: $e\n$st',
        tag: 'SupabaseCheckInRemoteDataSource',
      );
      return null;
    }
  }
}
