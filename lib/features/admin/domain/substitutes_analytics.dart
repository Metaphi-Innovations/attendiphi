import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/utils/validators.dart';
import '../../checkin/domain/entities/check_in_submission.dart';
import '../../employee/domain/employee_lookup.dart';
import '../../employee/domain/entities/employee.dart';
import 'substitute_check_in_mapping.dart';

/// Sort options for the Substitutes overview list.
enum SubstituteSortOption {
  visitsDesc('Most visits'),
  nameAsc('Name A–Z'),
  lastAttendanceDesc('Most recent');

  const SubstituteSortOption(this.label);
  final String label;
}

/// One valid substitute check-in after identity resolution.
class SubstituteVisitRecord {
  const SubstituteVisitRecord({
    required this.checkInId,
    required this.attendedAt,
    required this.substituteDisplayName,
    required this.substitutePhoneDisplay,
    required this.coveredMemberKey,
    required this.coveredMemberDisplayName,
    this.coveredMemberId,
    this.photoBase64,
    this.photoPath,
    this.hasPhoto = false,
    this.locationName,
    this.isVerified = false,
    this.isFlagged = false,
    this.faceVerified = false,
  });

  final String checkInId;
  final DateTime attendedAt;
  final String substituteDisplayName;
  final String substitutePhoneDisplay;
  final String coveredMemberKey;
  final String coveredMemberDisplayName;
  final String? coveredMemberId;
  final String? photoBase64;
  final String? photoPath;
  final bool hasPhoto;
  final String? locationName;
  final bool isVerified;
  final bool isFlagged;
  final bool faceVerified;

  /// Human status for tables (not color-only).
  String get statusLabel {
    if (isFlagged) return 'Flagged';
    if (isVerified) return 'Verified';
    return 'Recorded';
  }
}

/// Visits for one covered member under a single substitute.
class SubstituteMemberGroup {
  const SubstituteMemberGroup({
    required this.memberKey,
    required this.memberDisplayName,
    required this.memberId,
    required this.visits,
  });

  final String memberKey;
  final String memberDisplayName;
  final String? memberId;
  final List<SubstituteVisitRecord> visits;

  int get visitCount => visits.length;
}

/// Aggregated profile for one distinct substitute attendee.
class SubstituteProfile {
  const SubstituteProfile({
    required this.identityKey,
    required this.displayName,
    required this.phoneDisplay,
    required this.visits,
    required this.memberGroups,
  });

  final String identityKey;
  final String displayName;
  final String phoneDisplay;
  final List<SubstituteVisitRecord> visits;
  final List<SubstituteMemberGroup> memberGroups;

  int get totalVisits => visits.length;
  int get uniqueMembersCovered => memberGroups.length;

  DateTime? get firstAttendance =>
      visits.isEmpty ? null : visits.last.attendedAt;
  DateTime? get lastAttendance =>
      visits.isEmpty ? null : visits.first.attendedAt;

  String? get latestPhotoBase64 {
    for (final visit in visits) {
      final photo = visit.photoBase64?.trim() ?? '';
      if (photo.isNotEmpty) return photo;
    }
    return null;
  }

  /// Most recent visit that has a Storage path or inline photo.
  SubstituteVisitRecord? get latestVisitWithPhoto {
    for (final visit in visits) {
      if (visit.hasPhoto ||
          (visit.photoPath?.trim().isNotEmpty ?? false) ||
          (visit.photoBase64?.trim().isNotEmpty ?? false)) {
        return visit;
      }
    }
    return null;
  }

  /// Location from the most recent visit that has one.
  String? get latestLocationName {
    for (final visit in visits) {
      final name = visit.locationName?.trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    return null;
  }

  /// Status from the most recent visit.
  String? get latestStatusLabel =>
      visits.isEmpty ? null : visits.first.statusLabel;

  bool get latestFaceVerified => visits.isNotEmpty && visits.first.faceVerified;
}

/// Overview metrics for the Substitutes dashboard.
class SubstitutesAnalyticsSummary {
  const SubstitutesAnalyticsSummary({
    required this.uniqueSubstitutes,
    required this.totalVisits,
    required this.membersCovered,
    this.mostFrequent,
  });

  final int uniqueSubstitutes;
  final int totalVisits;
  final int membersCovered;
  final SubstituteProfile? mostFrequent;
}

/// Full analytics result from raw check-ins + roster.
class SubstitutesAnalytics {
  const SubstitutesAnalytics({required this.profiles, required this.summary});

  final List<SubstituteProfile> profiles;
  final SubstitutesAnalyticsSummary summary;
}

/// Consistent phone display: `XXXXX XXXXX` (no country code; empty if invalid).
String formatSubstitutePhoneDisplay(String? raw) {
  final normalized = Validators.normalizePhone(raw ?? '');
  if (normalized.length != 10) {
    final trimmed = (raw ?? '').trim();
    // Strip a leading +91 if present so the column never shows the country code.
    return trimmed
        .replaceFirst(RegExp(r'^\+?91[\s\-]*'), '')
        .trim();
  }
  return '${normalized.substring(0, 5)} ${normalized.substring(5)}';
}

/// True when [name] is empty or looks like a phone number (not a person name).
bool isPhoneLikeSubstituteName(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty) return true;
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 10 && digits.length <= 12) {
    // Entire label is essentially digits / +91 noise.
    final nonDigit = trimmed.replaceAll(RegExp(r'[\d\s+\-()]'), '');
    return nonDigit.isEmpty;
  }
  return false;
}

/// Display name for SUBSTITUTE column — never a raw phone string.
String substituteDisplayNameOrFallback(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty || isPhoneLikeSubstituteName(trimmed)) {
    return 'Unknown substitute';
  }
  return trimmed;
}

/// Seed / legacy identity key (not used alone for merging).
///
/// Prefer a composite when phone+name exist so deep links stay readable;
/// never use phone-only (that caused wrong merges).
String substituteIdentityKey({
  required String? phone,
  required String? displayName,
  required String fallbackRecordId,
}) {
  final normalizedPhone = Validators.normalizePhone(phone ?? '');
  final normalizedName = EmployeeLookup.normalizeName(displayName);
  final id = fallbackRecordId.trim();
  if (normalizedPhone.length >= 10 &&
      normalizedName.isNotEmpty &&
      !isPhoneLikeSubstituteName(displayName)) {
    return 'pn:$normalizedPhone:${normalizedName.replaceAll(' ', '_')}';
  }
  if (id.isNotEmpty) return 'c:$id';
  if (normalizedPhone.length >= 10) return 'p:$normalizedPhone';
  if (normalizedName.isNotEmpty) return 'n:$normalizedName';
  return 'unknown';
}

/// Phone signal: normalized last-10 equal.
bool substitutePhoneSignalMatch(String? a, String? b) {
  final left = Validators.normalizePhone(a ?? '');
  final right = Validators.normalizePhone(b ?? '');
  if (left.length < 10 || right.length < 10) return false;
  return left == right;
}

/// Name signal: exact normalized equality or strong token-subset similarity.
///
/// "Omkar" vs "Omkar Anarse" matches; weak partials like "As" do not.
bool substituteNameSignalMatch(String? a, String? b) {
  final left = EmployeeLookup.normalizeName(a);
  final right = EmployeeLookup.normalizeName(b);
  if (left.isEmpty || right.isEmpty) return false;
  if (isPhoneLikeSubstituteName(a) || isPhoneLikeSubstituteName(b)) {
    return false;
  }
  if (left == right) return true;
  final leftTokens = left.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final rightTokens = right.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  final shorter = leftTokens.length <= rightTokens.length
      ? leftTokens.toList()
      : rightTokens.toList();
  final longer = leftTokens.length <= rightTokens.length
      ? rightTokens.toList()
      : leftTokens.toList();
  if (shorter.isEmpty) return false;
  // Strong similarity: every token of the shorter name appears in the longer.
  var from = 0;
  for (final token in shorter) {
    final idx = longer.indexOf(token, from);
    if (idx < 0) return false;
    from = idx + 1;
  }
  return true;
}

/// Photo fingerprint for equality (path preferred, else hash of base64).
String? substitutePhotoFingerprint({
  String? photoPath,
  String? photoBase64,
}) {
  final path = photoPath?.trim() ?? '';
  if (path.isNotEmpty) return 'path:$path';
  final b64 = photoBase64?.trim() ?? '';
  if (b64.isEmpty) return null;
  final digest = sha256.convert(utf8.encode(b64)).toString();
  return 'b64:$digest';
}

/// Photo signal: both sides have a fingerprint and they are equal.
bool substitutePhotoSignalMatch({
  String? pathA,
  String? base64A,
  String? pathB,
  String? base64B,
}) {
  final left = substitutePhotoFingerprint(
    photoPath: pathA,
    photoBase64: base64A,
  );
  final right = substitutePhotoFingerprint(
    photoPath: pathB,
    photoBase64: base64B,
  );
  if (left == null || right == null) return false;
  return left == right;
}

/// Score 0–3 for phone / name / photo signals (order fixed for tie-breaks).
({int score, bool phone, bool name, bool photo}) scoreSubstituteIdentityMatch({
  required String? phoneA,
  required String? nameA,
  String? photoPathA,
  String? photoBase64A,
  required String? phoneB,
  required String? nameB,
  String? photoPathB,
  String? photoBase64B,
}) {
  final phone = substitutePhoneSignalMatch(phoneA, phoneB);
  final name = substituteNameSignalMatch(nameA, nameB);
  final photo = substitutePhotoSignalMatch(
    pathA: photoPathA,
    base64A: photoBase64A,
    pathB: photoPathB,
    base64B: photoBase64B,
  );
  final score = (phone ? 1 : 0) + (name ? 1 : 0) + (photo ? 1 : 0);
  return (score: score, phone: phone, name: name, photo: photo);
}

String coveredMemberKey({
  required String? memberId,
  required String? memberName,
}) {
  final id = (memberId ?? '').trim();
  if (id.isNotEmpty) return 'm:$id';
  final name = EmployeeLookup.normalizeName(memberName);
  if (name.isNotEmpty) return 'n:$name';
  return 'unknown';
}

/// Whether a check-in counts as a valid substitute visit (mirrors dashboard).
bool isValidSubstituteCheckIn(CheckInSubmission record) {
  if (!record.type.isSubstitute) return false;
  if (record.type.isVisitor) return false;
  if (CheckInSubmission.isPlaceholderId(record.id)) return false;
  return true;
}

/// Resolves attending substitute display fields from a raw check-in doc.
({String? name, String phone, String? displayLabel})
resolveSubstituteIdentityFields(CheckInSubmission record) {
  return resolveSubstituteAttendeeFields(
    displayed: record,
    raw: record,
    coveredMemberName: record.substituteForMember,
  );
}

class _SubstituteCluster {
  _SubstituteCluster({
    required this.key,
    required this.firstAttendedAt,
    required this.canonicalPhone,
    required this.canonicalName,
    required this.photoPath,
    required this.photoBase64,
  });

  final String key;
  final DateTime firstAttendedAt;
  String canonicalPhone;
  String canonicalName;
  String? photoPath;
  String? photoBase64;
  final visits = <SubstituteVisitRecord>[];

  void absorbSignals({
    required String phone,
    required String name,
    String? path,
    String? base64,
  }) {
    if (canonicalPhone.isEmpty && phone.isNotEmpty) {
      canonicalPhone = phone;
    }
    if ((canonicalName.isEmpty ||
            canonicalName == 'Unknown substitute' ||
            isPhoneLikeSubstituteName(canonicalName)) &&
        name.isNotEmpty &&
        !isPhoneLikeSubstituteName(name)) {
      canonicalName = name;
    }
    if ((photoPath == null || photoPath!.isEmpty) &&
        path != null &&
        path.trim().isNotEmpty) {
      photoPath = path.trim();
    }
    if ((photoBase64 == null || photoBase64!.isEmpty) &&
        base64 != null &&
        base64.trim().isNotEmpty) {
      photoBase64 = base64.trim();
    }
  }
}

/// Aggregates substitute check-ins into profiles (2-of-3 identity match).
SubstitutesAnalytics buildSubstitutesAnalytics({
  required List<CheckInSubmission> checkIns,
  List<Employee> employees = const [],
}) {
  final clusters = <_SubstituteCluster>[];
  final seenCheckInIds = <String>{};

  final ordered = List<CheckInSubmission>.from(checkIns)
    ..sort((a, b) {
      final atA = a.createdAt ?? a.timestamp;
      final atB = b.createdAt ?? b.timestamp;
      final cmp = atA.compareTo(atB);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

  for (final record in ordered) {
    if (!isValidSubstituteCheckIn(record)) continue;
    final id = record.id.trim();
    if (id.isEmpty || !seenCheckInIds.add(id)) continue;

    final identity = resolveSubstituteIdentityFields(record);
    final rawName = (identity.name ?? identity.displayLabel ?? '').trim();
    final displayName = substituteDisplayNameOrFallback(
      isPhoneLikeSubstituteName(rawName) ? null : rawName,
    );
    // Dedicated substitute phone only — never fall back to userPhone/member.
    final phoneRaw = identity.phone.trim().isNotEmpty
        ? identity.phone.trim()
        : (record.substitutePhone?.trim() ?? '');
    final phoneDisplay = formatSubstitutePhoneDisplay(phoneRaw);
    final photoPath = record.photoPath?.trim();
    final photoBase64 = record.photoBase64?.trim();

    // Find best cluster with score >= 2.
    _SubstituteCluster? best;
    var bestScore = 0;
    var bestPhone = false;
    var bestName = false;
    var bestPhoto = false;

    for (final cluster in clusters) {
      final scored = scoreSubstituteIdentityMatch(
        phoneA: phoneRaw,
        nameA: displayName == 'Unknown substitute' ? null : displayName,
        photoPathA: photoPath,
        photoBase64A: photoBase64,
        phoneB: cluster.canonicalPhone,
        nameB: cluster.canonicalName == 'Unknown substitute'
            ? null
            : cluster.canonicalName,
        photoPathB: cluster.photoPath,
        photoBase64B: cluster.photoBase64,
      );
      if (scored.score < 2) continue;
      final better =
          scored.score > bestScore ||
          (scored.score == bestScore &&
              scored.phone &&
              !bestPhone) ||
          (scored.score == bestScore &&
              scored.phone == bestPhone &&
              scored.name &&
              !bestName) ||
          (scored.score == bestScore &&
              scored.phone == bestPhone &&
              scored.name == bestName &&
              scored.photo &&
              !bestPhoto) ||
          (scored.score == bestScore &&
              scored.phone == bestPhone &&
              scored.name == bestName &&
              scored.photo == bestPhoto &&
              best != null &&
              cluster.firstAttendedAt.isBefore(best.firstAttendedAt));
      if (better || best == null) {
        best = cluster;
        bestScore = scored.score;
        bestPhone = scored.phone;
        bestName = scored.name;
        bestPhoto = scored.photo;
      }
    }

    final attendedAt = record.createdAt ?? record.timestamp;
    final covered = EmployeeLookup.forCheckIn(employees, record);
    final coveredName = (covered?.name.trim().isNotEmpty == true)
        ? covered!.name.trim()
        : (record.substituteForMember?.trim().isNotEmpty == true
              ? record.substituteForMember!.trim()
              : 'Unknown member');
    final memberKey = coveredMemberKey(
      memberId: covered?.id ?? record.memberId,
      memberName: coveredName,
    );

    final visit = SubstituteVisitRecord(
      checkInId: id,
      attendedAt: attendedAt,
      substituteDisplayName: displayName,
      substitutePhoneDisplay: phoneDisplay,
      coveredMemberKey: memberKey,
      coveredMemberDisplayName: coveredName,
      coveredMemberId: covered?.id ?? record.memberId,
      photoBase64: record.photoBase64,
      photoPath: record.photoPath,
      hasPhoto: record.hasPhoto ||
          (photoPath?.isNotEmpty ?? false) ||
          (photoBase64?.isNotEmpty ?? false),
      locationName: record.locationName.trim().isEmpty
          ? null
          : record.locationName.trim(),
      isVerified: record.isVerified,
      isFlagged: record.isFlagged,
      faceVerified: record.faceVerified,
    );

    if (best != null) {
      best.visits.add(visit);
      best.absorbSignals(
        phone: phoneRaw,
        name: displayName,
        path: photoPath,
        base64: photoBase64,
      );
    } else {
      final key = substituteIdentityKey(
        phone: phoneRaw,
        displayName: displayName == 'Unknown substitute' ? null : displayName,
        fallbackRecordId: id,
      );
      final cluster = _SubstituteCluster(
        key: key,
        firstAttendedAt: attendedAt,
        canonicalPhone: phoneRaw,
        canonicalName: displayName,
        photoPath: photoPath,
        photoBase64: photoBase64,
      );
      cluster.visits.add(visit);
      clusters.add(cluster);
    }
  }

  final profiles = <SubstituteProfile>[];
  final allCoveredMemberKeys = <String>{};

  for (final cluster in clusters) {
    final visits = List<SubstituteVisitRecord>.from(cluster.visits)
      ..sort((a, b) => b.attendedAt.compareTo(a.attendedAt));

    final byMember = <String, List<SubstituteVisitRecord>>{};
    final memberNames = <String, String>{};
    final memberIds = <String, String?>{};
    for (final visit in visits) {
      byMember.putIfAbsent(visit.coveredMemberKey, () => []).add(visit);
      memberNames[visit.coveredMemberKey] = visit.coveredMemberDisplayName;
      memberIds[visit.coveredMemberKey] = visit.coveredMemberId;
      allCoveredMemberKeys.add(visit.coveredMemberKey);
    }

    final groups = byMember.entries.map((e) {
      final memberVisits = List<SubstituteVisitRecord>.from(e.value)
        ..sort((a, b) => b.attendedAt.compareTo(a.attendedAt));
      return SubstituteMemberGroup(
        memberKey: e.key,
        memberDisplayName: memberNames[e.key] ?? 'Unknown member',
        memberId: memberIds[e.key],
        visits: memberVisits,
      );
    }).toList()
      ..sort((a, b) {
        final byCount = b.visitCount.compareTo(a.visitCount);
        if (byCount != 0) return byCount;
        return a.memberDisplayName.toLowerCase().compareTo(
          b.memberDisplayName.toLowerCase(),
        );
      });

    assert(
      groups.fold<int>(0, (sum, g) => sum + g.visitCount) == visits.length,
    );

    // Prefer the longest real person name among visits (e.g. Omkar Anarse).
    var displayName = cluster.canonicalName;
    for (final v in visits) {
      final candidate = v.substituteDisplayName.trim();
      if (isPhoneLikeSubstituteName(candidate) ||
          candidate == 'Unknown substitute') {
        continue;
      }
      if (isPhoneLikeSubstituteName(displayName) ||
          displayName == 'Unknown substitute' ||
          candidate.length > displayName.length) {
        displayName = candidate;
      }
    }

    profiles.add(
      SubstituteProfile(
        identityKey: cluster.key,
        displayName: substituteDisplayNameOrFallback(displayName),
        phoneDisplay: formatSubstitutePhoneDisplay(cluster.canonicalPhone),
        visits: visits,
        memberGroups: groups,
      ),
    );
  }

  profiles.sort((a, b) {
    final byVisits = b.totalVisits.compareTo(a.totalVisits);
    if (byVisits != 0) return byVisits;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });

  final totalVisits = profiles.fold<int>(0, (sum, p) => sum + p.totalVisits);

  return SubstitutesAnalytics(
    profiles: profiles,
    summary: SubstitutesAnalyticsSummary(
      uniqueSubstitutes: profiles.length,
      totalVisits: totalVisits,
      membersCovered: allCoveredMemberKeys.length,
      mostFrequent: profiles.isEmpty ? null : profiles.first,
    ),
  );
}

/// Filters and sorts substitute profiles for the overview UI.
List<SubstituteProfile> filterAndSortSubstituteProfiles({
  required List<SubstituteProfile> profiles,
  String searchQuery = '',
  DateTime? rangeStart,
  DateTime? rangeEnd,
  String? coveredMemberKeyFilter,
  SubstituteSortOption sort = SubstituteSortOption.visitsDesc,
}) {
  final query = searchQuery.trim().toLowerCase();
  final queryDigits = Validators.normalizePhone(searchQuery);

  bool inRange(DateTime at) {
    if (rangeStart != null) {
      final start = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
      if (at.isBefore(start)) return false;
    }
    if (rangeEnd != null) {
      final endExclusive = DateTime(
        rangeEnd.year,
        rangeEnd.month,
        rangeEnd.day,
      ).add(const Duration(days: 1));
      if (!at.isBefore(endExclusive)) return false;
    }
    return true;
  }

  final filtered = <SubstituteProfile>[];
  for (final profile in profiles) {
    var visits = profile.visits.where((v) => inRange(v.attendedAt)).toList();
    if (coveredMemberKeyFilter != null &&
        coveredMemberKeyFilter.trim().isNotEmpty) {
      visits = visits
          .where((v) => v.coveredMemberKey == coveredMemberKeyFilter)
          .toList();
    }
    if (visits.isEmpty &&
        (rangeStart != null ||
            rangeEnd != null ||
            (coveredMemberKeyFilter?.trim().isNotEmpty ?? false))) {
      continue;
    }

    if (query.isNotEmpty) {
      final nameHit = profile.displayName.toLowerCase().contains(query);
      final phoneHit = queryDigits.isNotEmpty &&
          Validators.normalizePhone(profile.phoneDisplay).contains(queryDigits);
      final memberHit = profile.memberGroups.any(
        (g) => g.memberDisplayName.toLowerCase().contains(query),
      );
      final visitMemberHit = visits.any(
        (v) => v.coveredMemberDisplayName.toLowerCase().contains(query),
      );
      if (!nameHit && !phoneHit && !memberHit && !visitMemberHit) {
        continue;
      }
    }

    if (rangeStart != null ||
        rangeEnd != null ||
        (coveredMemberKeyFilter?.trim().isNotEmpty ?? false)) {
      final byMember = <String, List<SubstituteVisitRecord>>{};
      for (final visit in visits) {
        byMember.putIfAbsent(visit.coveredMemberKey, () => []).add(visit);
      }
      final groups = byMember.entries.map((e) {
        final memberVisits = List<SubstituteVisitRecord>.from(e.value)
          ..sort((a, b) => b.attendedAt.compareTo(a.attendedAt));
        return SubstituteMemberGroup(
          memberKey: e.key,
          memberDisplayName: memberVisits.first.coveredMemberDisplayName,
          memberId: memberVisits.first.coveredMemberId,
          visits: memberVisits,
        );
      }).toList()
        ..sort((a, b) => b.visitCount.compareTo(a.visitCount));

      filtered.add(
        SubstituteProfile(
          identityKey: profile.identityKey,
          displayName: profile.displayName,
          phoneDisplay: formatSubstitutePhoneDisplay(profile.phoneDisplay),
          visits: List<SubstituteVisitRecord>.from(visits)
            ..sort((a, b) => b.attendedAt.compareTo(a.attendedAt)),
          memberGroups: groups,
        ),
      );
    } else {
      filtered.add(profile);
    }
  }

  filtered.sort((a, b) {
    switch (sort) {
      case SubstituteSortOption.nameAsc:
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
      case SubstituteSortOption.lastAttendanceDesc:
        final aLast =
            a.lastAttendance ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bLast =
            b.lastAttendance ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = bLast.compareTo(aLast);
        if (cmp != 0) return cmp;
        return b.totalVisits.compareTo(a.totalVisits);
      case SubstituteSortOption.visitsDesc:
        final cmp = b.totalVisits.compareTo(a.totalVisits);
        if (cmp != 0) return cmp;
        return a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        );
    }
  });

  return filtered;
}
