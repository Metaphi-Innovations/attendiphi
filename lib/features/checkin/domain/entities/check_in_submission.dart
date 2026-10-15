import 'check_in_type.dart';

/// Domain entity representing a validated attendance check-in submission.
class CheckInSubmission {
  const CheckInSubmission({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.userName,
    required this.userPhone,
    required this.type,
    required this.userLatitude,
    required this.userLongitude,
    required this.gpsAccuracy,
    required this.distanceMeters,
    required this.timestamp,
    this.userEmail,
    this.substituteForMember,
    this.substituteName,
    this.substitutePhone,
    this.companyName,
    this.category,
    this.invitedByMember,
    this.photoBase64,
    this.photoPath,
    this.hasPhoto = false,
    this.adminId,
    this.deviceId,
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.isEdited = false,
    this.editedAt,
    this.createdAt,
    this.isFlagged = false,
    this.flagReason,
    this.memberId,
    this.verificationMethod,
    this.faceVerified = false,
  });

  /// Client-generated unique UUID for idempotency.
  final String id;

  /// Target location ID (e.g. "location_x").
  final String locationId;

  /// Target location display name (e.g. "Excel Plaza, Ghatkopar").
  final String locationName;

  /// Unique ID of the Admin whose workspace this check-in belongs to.
  final String? adminId;

  /// Device UUID that created this submission (for server-side duplicate detection).
  final String? deviceId;

  /// User's full name.
  final String userName;

  /// User's 10-digit Indian phone number (+91).
  final String userPhone;

  /// Check-in type (Member, Substitute, or Visitor).
  final CheckInType type;

  /// User's GPS latitude at time of check-in.
  final double userLatitude;

  /// User's GPS longitude at time of check-in.
  final double userLongitude;

  /// GPS reading accuracy in meters.
  final double gpsAccuracy;

  /// Verified distance in meters from venue center.
  final double distanceMeters;

  /// Timestamp of the submission.
  final DateTime timestamp;

  /// Optional email address.
  final String? userEmail;

  /// Member name that the substitute is standing in for.
  final String? substituteForMember;

  /// Full name of the substitute person (when type is substitute).
  final String? substituteName;

  /// Phone typed by the substitute at check-in (never the covered member roster).
  ///
  /// Kept separate from [userPhone] so member-profile sync cannot overwrite it.
  final String? substitutePhone;

  /// Company or organization name (for visitors).
  final String? companyName;

  /// Business category or industry (for visitors).
  final String? category;

  /// Member name who invited the visitor.
  final String? invitedByMember;

  /// Base64 encoded compressed JPEG face photo (capture pipeline only).
  final String? photoBase64;

  /// Supabase Storage object path under `check-in-photos`.
  final String? photoPath;

  /// True when a selfie exists in Storage (or legacy base64).
  final bool hasPhoto;

  /// Whether an admin has verified this attendee's presence.
  final bool isVerified;

  /// Timestamp when verified by admin.
  final DateTime? verifiedAt;

  /// Admin identifier who verified.
  final String? verifiedBy;

  /// Whether this record was edited by an admin.
  final bool isEdited;

  /// Timestamp when last edited by an admin.
  final DateTime? editedAt;

  /// The true server-side creation time.
  final DateTime? createdAt;

  /// Whether this record is flagged as suspicious or invalid by an admin.
  final bool isFlagged;

  /// Optional reason why this record was flagged.
  final String? flagReason;

  /// Selected member document id (manual dropdown selection).
  final String? memberId;

  /// How identity was verified (e.g. `face`). Existing QR/manual records omit this.
  final String? verificationMethod;

  /// True when this check-in was produced after a successful face match.
  final bool faceVerified;

  CheckInSubmission copyWith({
    String? id,
    String? locationId,
    String? locationName,
    String? userName,
    String? userPhone,
    CheckInType? type,
    double? userLatitude,
    double? userLongitude,
    double? gpsAccuracy,
    double? distanceMeters,
    DateTime? timestamp,
    String? userEmail,
    String? substituteForMember,
    String? substituteName,
    String? substitutePhone,
    String? companyName,
    String? category,
    String? invitedByMember,
    String? photoBase64,
    String? photoPath,
    bool? hasPhoto,
    String? adminId,
    String? deviceId,
    bool? isVerified,
    DateTime? verifiedAt,
    String? verifiedBy,
    bool? isEdited,
    DateTime? editedAt,
    DateTime? createdAt,
    bool? isFlagged,
    String? flagReason,
    String? memberId,
    String? verificationMethod,
    bool? faceVerified,
    bool clearSubstituteFields = false,
    bool clearSubstituteName = false,
    bool clearSubstitutePhone = false,
    bool clearVerificationMeta = false,
  }) {
    return CheckInSubmission(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      type: type ?? this.type,
      userLatitude: userLatitude ?? this.userLatitude,
      userLongitude: userLongitude ?? this.userLongitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      timestamp: timestamp ?? this.timestamp,
      userEmail: userEmail ?? this.userEmail,
      substituteForMember: clearSubstituteFields
          ? null
          : (substituteForMember ?? this.substituteForMember),
      substituteName: (clearSubstituteFields || clearSubstituteName)
          ? null
          : (substituteName ?? this.substituteName),
      substitutePhone: (clearSubstituteFields || clearSubstitutePhone)
          ? null
          : (substitutePhone ?? this.substitutePhone),
      companyName: companyName ?? this.companyName,
      category: category ?? this.category,
      invitedByMember: invitedByMember ?? this.invitedByMember,
      photoBase64: photoBase64 ?? this.photoBase64,
      photoPath: photoPath ?? this.photoPath,
      hasPhoto: hasPhoto ?? this.hasPhoto,
      adminId: adminId ?? this.adminId,
      deviceId: deviceId ?? this.deviceId,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: clearVerificationMeta
          ? null
          : (verifiedAt ?? this.verifiedAt),
      verifiedBy: clearVerificationMeta
          ? null
          : (verifiedBy ?? this.verifiedBy),
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt ?? this.createdAt,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      memberId: memberId ?? this.memberId,
      verificationMethod: verificationMethod ?? this.verificationMethod,
      faceVerified: faceVerified ?? this.faceVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'locationId': locationId,
      'locationName': locationName,
      'userName': userName,
      'userPhone': userPhone,
      'type': type.name,
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'gpsAccuracy': gpsAccuracy,
      'distanceMeters': distanceMeters,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'userEmail': userEmail,
      'substituteForMember': substituteForMember,
      'substituteName': substituteName,
      'substitutePhone': substitutePhone,
      'companyName': companyName,
      'category': category,
      'invitedByMember': invitedByMember,
      'photoBase64': photoBase64,
      'photoPath': photoPath,
      'hasPhoto': hasPhoto,
      'adminId': adminId,
      'deviceId': deviceId,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt?.toUtc().toIso8601String(),
      'verifiedBy': verifiedBy,
      'isEdited': isEdited,
      'editedAt': editedAt?.toUtc().toIso8601String(),
      'createdAt': createdAt?.toUtc().toIso8601String(),
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      if (memberId != null) 'memberId': memberId,
      if (verificationMethod != null) 'verificationMethod': verificationMethod,
      'faceVerified': faceVerified,
    };
  }

  /// Firestore-safe payload: omits null optional fields.
  ///
  /// Use this (not [toMap]) for `set` / `update` — Firestore rejects nulls on
  /// `update`, and public create rules use a tight allowlist.
  Map<String, dynamic> toFirestoreMap() {
    final map = toMap()..removeWhere((_, value) => value == null);
    return map;
  }

  /// Whether this id is a Daily Attendance placeholder (not a Firestore doc).
  static bool isPlaceholderId(String id) => id.startsWith('not_checked_in_');

  factory CheckInSubmission.fromMap(Map<String, dynamic> map) {
    CheckInType parseType(dynamic val) {
      if (val == 'substitute') return CheckInType.substitute;
      if (val == 'visitor') return CheckInType.visitor;
      if (val == 'absent') return CheckInType.absent;
      if (val == 'notCheckedIn') return CheckInType.notCheckedIn;
      return CheckInType.member;
    }

    return CheckInSubmission(
      id: map['id']?.toString() ?? '',
      locationId: map['locationId']?.toString() ?? '',
      locationName: map['locationName']?.toString() ?? '',
      userName: map['userName']?.toString() ?? '',
      userPhone: map['userPhone']?.toString() ?? '',
      type: parseType(map['type']),
      userLatitude: (map['userLatitude'] as num?)?.toDouble() ?? 0.0,
      userLongitude: (map['userLongitude'] as num?)?.toDouble() ?? 0.0,
      gpsAccuracy: (map['gpsAccuracy'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      timestamp:
          (DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
                  DateTime.now())
              .toLocal(),
      userEmail: map['userEmail']?.toString(),
      substituteForMember: map['substituteForMember']?.toString(),
      substituteName: map['substituteName']?.toString(),
      substitutePhone: map['substitutePhone']?.toString(),
      companyName: map['companyName']?.toString(),
      category: map['category']?.toString(),
      invitedByMember: map['invitedByMember']?.toString(),
      photoBase64: map['photoBase64']?.toString(),
      photoPath: map['photoPath']?.toString(),
      hasPhoto:
          map['hasPhoto'] == true ||
          ((map['photoPath']?.toString().trim().isNotEmpty ?? false) ||
              (map['photoBase64']?.toString().trim().isNotEmpty ?? false)),
      adminId: map['adminId']?.toString(),
      deviceId: map['deviceId']?.toString(),
      isVerified: map['isVerified'] == true,
      verifiedAt: DateTime.tryParse(map['verifiedAt']?.toString() ?? '')
          ?.toLocal(),
      verifiedBy: map['verifiedBy']?.toString(),
      isEdited: map['isEdited'] == true,
      editedAt: DateTime.tryParse(map['editedAt']?.toString() ?? '')?.toLocal(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '')
          ?.toLocal(),
      isFlagged: map['isFlagged'] == true,
      flagReason: map['flagReason']?.toString(),
      memberId: map['memberId']?.toString(),
      verificationMethod: map['verificationMethod']?.toString(),
      faceVerified: map['faceVerified'] == true,
    );
  }
}
