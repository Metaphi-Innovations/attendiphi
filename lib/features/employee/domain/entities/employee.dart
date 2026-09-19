/// Domain entity representing an Employee / User for attendance check-ins.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.role = 'Member',
    this.designation = '',
    this.isActive = true,
    this.adminId,
    this.photoUrl,
    this.faceEmbedding,
    this.faceTemplates,
    this.faceEnrolled = false,
    this.faceModel,
    this.faceModelVersion,
    this.createdAt,
    this.updatedAt,
  });

  /// Unique employee document ID.
  final String id;

  /// Full employee name.
  final String name;

  /// Optional email address.
  final String email;

  /// Optional contact phone number.
  final String phone;

  /// Role (e.g. 'Member', 'Staff', 'Admin', 'Substitute', 'Super Admin').
  final String role;

  /// Optional job title / designation (e.g. 'Flutter Developer', 'QA', etc.).
  final String designation;

  /// Whether the employee is currently active.
  final bool isActive;

  /// Unique ID of the Admin account whose workspace this employee belongs to.
  final String? adminId;

  /// Optional profile/face photo URL.
  final String? photoUrl;

  /// Primary or legacy biometric face embedding vector.
  final List<double>? faceEmbedding;

  /// Multi-frame biometric templates (3-5 live SFace 128-d embeddings).
  final List<List<double>>? faceTemplates;

  /// Returns all available biometric templates for this employee.
  List<List<double>> get allFaceTemplates {
    if (faceTemplates != null && faceTemplates!.isNotEmpty) {
      return faceTemplates!;
    }
    if (faceEmbedding != null && faceEmbedding!.isNotEmpty) {
      return [faceEmbedding!];
    }
    return const [];
  }

  /// Whether member has a validated neural biometric enrollment template.
  final bool faceEnrolled;

  /// Name of the biometric face model used for enrollment (e.g. 'sface').
  final String? faceModel;

  /// Version of the biometric face model used for enrollment (e.g. '2021dec').
  final String? faceModelVersion;

  /// Timestamp when employee was added.
  final DateTime? createdAt;

  /// Timestamp when employee was last updated.
  final DateTime? updatedAt;

  Employee copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? designation,
    bool? isActive,
    String? adminId,
    String? photoUrl,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    bool? faceEnrolled,
    String? faceModel,
    String? faceModelVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      isActive: isActive ?? this.isActive,
      adminId: adminId ?? this.adminId,
      photoUrl: photoUrl ?? this.photoUrl,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
      faceTemplates: faceTemplates ?? this.faceTemplates,
      faceEnrolled: faceEnrolled ?? this.faceEnrolled,
      faceModel: faceModel ?? this.faceModel,
      faceModelVersion: faceModelVersion ?? this.faceModelVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'designation': designation,
      'isActive': isActive,
      'adminId': adminId,
      'faceEnrolled': faceEnrolled,
      if (faceModel != null) 'faceModel': faceModel,
      if (faceModelVersion != null) 'faceModelVersion': faceModelVersion,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (faceEmbedding != null) 'faceEmbedding': faceEmbedding,
      if (faceTemplates != null) 'faceTemplates': faceTemplates,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map, {String? docId}) {
    List<double>? parsedEmbedding;
    if (map['faceEmbedding'] is List) {
      parsedEmbedding = (map['faceEmbedding'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    List<List<double>>? parsedTemplates;
    if (map['faceTemplates'] is List) {
      parsedTemplates = (map['faceTemplates'] as List)
          .whereType<List>()
          .map((t) => t.map((e) => (e as num).toDouble()).toList())
          .toList();
    }

    final bool isEnrolled = map['faceEnrolled'] as bool? ??
        ((parsedTemplates != null && parsedTemplates.isNotEmpty) ||
         (parsedEmbedding != null && parsedEmbedding.isNotEmpty));

    return Employee(
      id: docId ?? map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? 'Member',
      designation: map['designation']?.toString() ?? '',
      isActive: map['isActive'] as bool? ?? true,
      adminId: map['adminId']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      faceEmbedding: parsedEmbedding,
      faceTemplates: parsedTemplates,
      faceEnrolled: isEnrolled,
      faceModel: map['faceModel']?.toString(),
      faceModelVersion: map['faceModelVersion']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
