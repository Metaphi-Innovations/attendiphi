import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/employee/domain/public_member_projection.dart';

void main() {
  group('PublicMemberProjection', () {
    test('actionFor upserts active and removes inactive', () {
      expect(
        PublicMemberProjection.actionFor(isActive: true),
        PublicMemberProjectionAction.upsert,
      );
      expect(
        PublicMemberProjection.actionFor(isActive: false),
        PublicMemberProjectionAction.remove,
      );
    });

    test('toMap includes only public QR fields with isActive true', () {
      final map = PublicMemberProjection.toMap(
        id: ' emp_1 ',
        name: ' Rohan Mehta ',
        phone: ' 9876543210 ',
        updatedAt: DateTime.utc(2026, 10, 9, 12),
      );

      expect(map.keys.toSet(), PublicMemberProjection.allowedKeys);
      expect(map['id'], 'emp_1');
      expect(map['name'], 'Rohan Mehta');
      expect(map['phone'], '9876543210');
      expect(map['isActive'], isTrue);
      expect(map['updatedAt'], '2026-10-09T12:00:00.000Z');
    });

    test('toMap never carries private employee fields', () {
      final map = PublicMemberProjection.toMap(
        id: 'e1',
        name: 'A',
        phone: '9000000000',
      );
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('photoUrl'), isFalse);
      expect(map.containsKey('faceEmbedding'), isFalse);
      expect(map.containsKey('faceTemplates'), isFalse);
      expect(map.containsKey('adminId'), isFalse);
    });

    test('keysAreAllowed rejects email and biometrics', () {
      expect(
        PublicMemberProjection.keysAreAllowed(['id', 'name', 'phone']),
        isTrue,
      );
      expect(
        PublicMemberProjection.keysAreAllowed([
          'id',
          'name',
          'phone',
          'isActive',
          'updatedAt',
        ]),
        isTrue,
      );
      expect(
        PublicMemberProjection.keysAreAllowed(['id', 'name', 'email']),
        isFalse,
      );
      expect(
        PublicMemberProjection.keysAreAllowed(['id', 'faceEmbedding']),
        isFalse,
      );
    });

    test('reactivation is an upsert; deactivation is remove', () {
      expect(
        PublicMemberProjection.actionFor(isActive: false),
        PublicMemberProjectionAction.remove,
      );
      expect(
        PublicMemberProjection.actionFor(isActive: true),
        PublicMemberProjectionAction.upsert,
      );
    });

    test(
      'updated active projection keeps stable id and public fields only',
      () {
        final before = PublicMemberProjection.toMap(
          id: 'e1',
          name: 'Old Name',
          phone: '9000000000',
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        final after = PublicMemberProjection.toMap(
          id: 'e1',
          name: 'New Name',
          phone: '9000000001',
          updatedAt: DateTime.utc(2026, 10, 9),
        );
        expect(after['id'], before['id']);
        expect(after['name'], 'New Name');
        expect(after['phone'], '9000000001');
        expect(after['isActive'], isTrue);
        expect(PublicMemberProjection.keysAreAllowed(after.keys), isTrue);
      },
    );

    test(
      'deletion/removal is modeled as remove action (no public payload)',
      () {
        expect(
          PublicMemberProjection.actionFor(isActive: false),
          PublicMemberProjectionAction.remove,
        );
        expect(PublicMemberProjection.allowedKeys.contains('email'), isFalse);
      },
    );
  });
}
