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

  /// 192-dimension normalized biometric face embedding vector.
  final List<double>? faceEmbedding;

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
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (faceEmbedding != null) 'faceEmbedding': faceEmbedding,
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
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }
}
