import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/substitute_check_in_mapping.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

CheckInSubmission _raw({
  required String userName,
  required String phone,
  String? substituteForMember,
  String? substituteName,
  String? memberId,
  String? photoBase64,
}) {
  return CheckInSubmission(
    id: 'sub-1',
    locationId: 'loc',
    locationName: 'Venue',
    userName: userName,
    userPhone: phone,
    type: CheckInType.substitute,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 5,
    distanceMeters: 10,
    timestamp: DateTime(2026, 10, 8, 10, 0),
    substituteForMember: substituteForMember,
    substituteName: substituteName,
    memberId: memberId,
    photoBase64: photoBase64,
  );
}

void main() {
  const member = Employee(
    id: 'emp_member',
    name: 'Tejashree Vinayak Sane',
    phone: '9919055132',
    email: 'tejashree@example.com',
  );

  group('mapSubstituteCheckInForMember', () {
    test(
      'fresh QR write: userName is substitute, remaps member vs substitute',
      () {
        final raw = _raw(
          userName: 'Amit Patel',
          phone: '+919876543210',
          substituteForMember: 'Tejashree Vinayak Sane',
          photoBase64: 'selfie_bytes',
        );

        final mapped = mapSubstituteCheckInForMember(raw: raw, member: member);

        expect(mapped.userName, 'Tejashree Vinayak Sane');
        expect(mapped.substituteName, 'Amit Patel');
        expect(mapped.userName, isNot(mapped.substituteName));
        expect(mapped.userPhone, '+919876543210');
        expect(mapped.memberId, 'emp_member');
        expect(mapped.photoBase64, 'selfie_bytes');
        expect(mapped.substituteForMember, 'Tejashree Vinayak Sane');
      },
    );

    test('after verify write-back: prefers persisted substituteName over userName', () {
      // Bug scenario: remapped row was saved — userName is already the member.
      final raw = _raw(
        userName: 'Tejashree Vinayak Sane',
        phone: '9919055132',
        substituteForMember: 'Tejashree Vinayak Sane',
        substituteName: 'Amit Patel',
        memberId: 'emp_member',
        photoBase64: 'selfie_bytes',
      );

      final mapped = mapSubstituteCheckInForMember(raw: raw, member: member);

      expect(mapped.userName, 'Tejashree Vinayak Sane');
      expect(mapped.substituteName, 'Amit Patel');
      expect(mapped.userName, isNot(mapped.substituteName));
    });

    test('remapped write-back without substituteName does not invent attendee', () {
      final raw = _raw(
        userName: 'Tejashree Vinayak Sane',
        phone: '9919055132',
        substituteForMember: 'Tejashree Vinayak Sane',
        substituteName: null,
        memberId: 'emp_member',
      );

      final mapped = mapSubstituteCheckInForMember(raw: raw, member: member);

      expect(mapped.userName, 'Tejashree Vinayak Sane');
      // substituteForMember is set → not treated as admin flip; identity lost.
      expect(mapped.substituteName, isNull);
    });

    test('collapsed substituteName equal to member is cleared; phone kept', () {
      final raw = _raw(
        userName: 'Tejashree Vinayak Sane',
        phone: '9819055132',
        substituteForMember: 'Tejashree Vinayak Sane',
        substituteName: 'Tejashree Vinayak Sane',
        memberId: 'emp_member',
        photoBase64: 'selfie_of_other_person',
      ).copyWith(substitutePhone: '9819055132');

      final mapped = mapSubstituteCheckInForMember(raw: raw, member: member);

      expect(mapped.userName, 'Tejashree Vinayak Sane');
      // Do not duplicate Member Name into Substitute Name.
      expect(mapped.substituteName, isNull);
      expect(mapped.substitutePhone, '9819055132');
      expect(mapped.userPhone, '9819055132');
      expect(mapped.photoBase64, 'selfie_of_other_person');
    });

    test(
      'admin flip with empty substituteForMember does not invent member as sub',
      () {
        final raw = _raw(
          userName: 'Tejashree Vinayak Sane',
          phone: '9919055132',
          substituteForMember: null,
          substituteName: null,
          memberId: 'emp_member',
        );

        final mapped = mapSubstituteCheckInForMember(raw: raw, member: member);

        expect(mapped.userName, 'Tejashree Vinayak Sane');
        // No distinct attendee name available — leave null (UI shows "—").
        expect(mapped.substituteName, isNull);
        expect(mapped.substituteForMember, 'Tejashree Vinayak Sane');
      },
    );
  });

  group('substituteCheckInCoversMember', () {
    test('matches by substituteForMember name', () {
      final raw = _raw(
        userName: 'Amit Patel',
        phone: '+919876543210',
        substituteForMember: 'Tejashree Vinayak Sane',
      );
      expect(substituteCheckInCoversMember(raw: raw, member: member), isTrue);
    });

    test('matches by memberId when present', () {
      final raw = _raw(
        userName: 'Amit Patel',
        phone: '+919876543210',
        substituteForMember: 'Wrong Name',
        memberId: 'emp_member',
      );
      expect(substituteCheckInCoversMember(raw: raw, member: member), isTrue);
    });

    test('does not match unrelated member', () {
      const other = Employee(
        id: 'emp_other',
        name: 'Other Member',
        phone: '9000000000',
      );
      final raw = _raw(
        userName: 'Amit Patel',
        phone: '+919876543210',
        substituteForMember: 'Tejashree Vinayak Sane',
        memberId: 'emp_member',
      );
      expect(substituteCheckInCoversMember(raw: raw, member: other), isFalse);
    });

    test(
      'matches admin-converted substitute with empty substituteForMember',
      () {
        final raw = _raw(
          userName: 'Tejashree Vinayak Sane',
          phone: '9919055132',
          substituteForMember: null,
          memberId: null,
        );
        expect(substituteCheckInCoversMember(raw: raw, member: member), isTrue);
      },
    );
  });

  group('prepareAdminEditedCheckIn', () {
    final original = _raw(
      userName: 'Omkar Anarse',
      phone: '9976543215',
      memberId: 'emp_omkar',
      substituteForMember: null,
      substituteName: null,
    ).copyWith(type: CheckInType.member);

    const omkar = Employee(
      id: 'emp_omkar',
      name: 'Omkar Anarse',
      phone: '9976543215',
    );

    test('Member → Substitute keeps row attachable with substitute fields', () {
      final updated = prepareAdminEditedCheckIn(
        original: original,
        selectedType: CheckInType.substitute,
        nameField: 'Ravi Kumar',
        phoneField: '9976543215',
        venueField: 'Jade Luxury Banquets, Mumbai',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );

      expect(updated.type, CheckInType.substitute);
      expect(updated.memberId, 'emp_omkar');
      expect(updated.substituteForMember, 'Omkar Anarse');
      expect(updated.substituteName, 'Ravi Kumar');
      expect(updated.userName, 'Omkar Anarse');
      expect(
        substituteCheckInCoversMember(raw: updated, member: omkar),
        isTrue,
      );

      final mapped = mapSubstituteCheckInForMember(raw: updated, member: omkar);
      expect(mapped.type, CheckInType.substitute);
      expect(mapped.substituteName, 'Ravi Kumar');
      expect(mapped.memberId, 'emp_omkar');
    });

    test('Member → Substitute with different substitute name', () {
      final updated = prepareAdminEditedCheckIn(
        original: original,
        selectedType: CheckInType.substitute,
        nameField: 'Ravi Kumar',
        phoneField: '9000000001',
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );

      expect(updated.userName, 'Omkar Anarse');
      expect(updated.substituteForMember, 'Omkar Anarse');
      expect(updated.substituteName, 'Ravi Kumar');
      expect(updated.userPhone, '9000000001');
    });

    test('Substitute → Member clears substitute fields', () {
      final asSub = prepareAdminEditedCheckIn(
        original: original,
        selectedType: CheckInType.substitute,
        nameField: 'Ravi Kumar',
        phoneField: '9000000001',
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );
      final backToMember = prepareAdminEditedCheckIn(
        original: asSub,
        selectedType: CheckInType.member,
        nameField: 'Omkar Anarse',
        phoneField: '9976543215',
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );

      expect(backToMember.type, CheckInType.member);
      expect(backToMember.substituteForMember, isNull);
      expect(backToMember.substituteName, isNull);
      expect(backToMember.userName, 'Omkar Anarse');
    });

    test('Member → Absent clears substitute + verification meta', () {
      final verified = original.copyWith(
        isVerified: true,
        verifiedAt: DateTime(2026, 10, 8, 9),
        verifiedBy: 'Admin',
      );
      final updated = prepareAdminEditedCheckIn(
        original: verified,
        selectedType: CheckInType.absent,
        nameField: 'Omkar Anarse',
        phoneField: '9976543215',
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
        isVerified: true,
      );

      expect(updated.type, CheckInType.absent);
      expect(updated.memberId, 'emp_omkar');
      expect(updated.userName, 'Omkar Anarse');
      expect(updated.substituteForMember, isNull);
      expect(updated.substituteName, isNull);
      expect(updated.isVerified, isFalse);
      expect(updated.verifiedAt, isNull);
      expect(updated.verifiedBy, isNull);

      final firestoreMap = updated.toFirestoreMap();
      expect(firestoreMap.containsKey('substituteForMember'), isFalse);
      expect(firestoreMap.containsKey('substituteName'), isFalse);
      expect(firestoreMap.containsKey('verifiedAt'), isFalse);
      expect(firestoreMap['type'], 'absent');
      expect(firestoreMap['locationId'], isNotEmpty);
    });

    test('Substitute → Absent keeps covered member name', () {
      final asSub = prepareAdminEditedCheckIn(
        original: original,
        selectedType: CheckInType.substitute,
        nameField: 'Ravi Kumar',
        phoneField: '9000000001',
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );
      final absent = prepareAdminEditedCheckIn(
        original: asSub,
        selectedType: CheckInType.absent,
        nameField: 'Ravi Kumar',
        phoneField: '9000000001',
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );

      expect(absent.type, CheckInType.absent);
      expect(absent.userName, 'Omkar Anarse');
      expect(absent.memberId, 'emp_omkar');
      expect(absent.substituteName, isNull);
    });

    test('Not Checked In → Absent materializes real id + locationId', () {
      final placeholder = CheckInSubmission(
        id: 'not_checked_in_emp_omkar_123',
        locationId: '',
        locationName: '—',
        userName: omkar.name,
        userPhone: omkar.phone,
        type: CheckInType.notCheckedIn,
        userLatitude: 0,
        userLongitude: 0,
        gpsAccuracy: 0,
        distanceMeters: 0,
        timestamp: DateTime(2026, 10, 8),
        memberId: omkar.id,
      );

      final updated = prepareAdminEditedCheckIn(
        original: placeholder,
        selectedType: CheckInType.absent,
        nameField: omkar.name,
        phoneField: omkar.phone,
        venueField: '—',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
        newCheckInId: 'real-uuid-absent-1',
        fallbackLocationId: 'location_x',
        fallbackLocationName: 'Jade Luxury Banquets, Mumbai',
      );

      expect(updated.id, 'real-uuid-absent-1');
      expect(CheckInSubmission.isPlaceholderId(updated.id), isFalse);
      expect(updated.type, CheckInType.absent);
      expect(updated.locationId, 'location_x');
      expect(updated.locationName, isNot('—'));
      expect(updated.memberId, 'emp_omkar');

      final firestoreMap = updated.toFirestoreMap();
      expect(firestoreMap['id'], 'real-uuid-absent-1');
      expect(firestoreMap['locationId'], 'location_x');
      expect(firestoreMap.containsKey('substituteForMember'), isFalse);
    });

    test('Absent → Member produces member payload without null write keys', () {
      final absent = prepareAdminEditedCheckIn(
        original: original,
        selectedType: CheckInType.absent,
        nameField: omkar.name,
        phoneField: omkar.phone,
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );
      final asMember = prepareAdminEditedCheckIn(
        original: absent,
        selectedType: CheckInType.member,
        nameField: omkar.name,
        phoneField: omkar.phone,
        venueField: 'Venue',
        coveredMemberName: omkar.name,
        coveredMemberId: omkar.id,
      );

      expect(asMember.type, CheckInType.member);
      expect(asMember.toFirestoreMap()['type'], 'member');
      expect(asMember.toFirestoreMap().values.every((v) => v != null), isTrue);
    });
  });

  group('resolveSubstituteAttendeeFields', () {
    test('uses dedicated substitutePhone only (not userPhone)', () {
      final raw = _raw(
        userName: 'Amit Patel',
        phone: '9000000000',
        substituteForMember: 'Tejashree Vinayak Sane',
        substituteName: 'Amit Patel',
        memberId: 'emp_member',
      ).copyWith(substitutePhone: '9819055132');
      // Dashboard remapped row: userName already the covered member.
      final displayed = raw.copyWith(
        userName: 'Tejashree Vinayak Sane',
        userPhone: '9000000000',
        substituteName: 'Amit Patel',
        substitutePhone: '9819055132',
      );

      final fields = resolveSubstituteAttendeeFields(
        displayed: displayed,
        raw: raw,
        coveredMemberName: 'Tejashree Vinayak Sane',
      );

      expect(fields.name, 'Amit Patel');
      expect(fields.phone, '9819055132');
      expect(fields.displayLabel, 'Amit Patel');
    });

    test('falls back to raw userName when substituteName missing', () {
      final raw = _raw(
        userName: 'Amit Patel',
        phone: '9819055132',
        substituteForMember: 'Tejashree Vinayak Sane',
        substituteName: null,
        memberId: 'emp_member',
      ).copyWith(substitutePhone: '9819055132');
      final displayed = mapSubstituteCheckInForMember(raw: raw, member: member);

      final fields = resolveSubstituteAttendeeFields(
        displayed: displayed,
        raw: raw,
        coveredMemberName: member.name,
      );

      expect(fields.name, 'Amit Patel');
      expect(fields.phone, '9819055132');
      expect(fields.displayLabel, 'Amit Patel');
    });

    test('collapsed substituteName shows null name but keeps phone', () {
      final raw = _raw(
        userName: 'Tejashree Vinayak Sane',
        phone: '9819055132',
        substituteForMember: 'Tejashree Vinayak Sane',
        substituteName: 'Tejashree Vinayak Sane',
        memberId: 'emp_member',
        photoBase64: 'selfie',
      ).copyWith(substitutePhone: '9819055132');
      final displayed = mapSubstituteCheckInForMember(raw: raw, member: member);

      final fields = resolveSubstituteAttendeeFields(
        displayed: displayed,
        raw: raw,
        coveredMemberName: member.name,
        coveredMemberPhone: member.phone,
      );

      // Name collapsed to member → hide duplicate; phone stays in PHONE column only.
      expect(fields.name, isNull);
      expect(fields.phone, '9819055132');
      expect(fields.displayLabel, isNull);
    });

    test(
      'null substitutePhone does not fall back to member/userPhone',
      () {
        final raw = _raw(
          userName: 'Alzaba Feroz',
          phone: '9920734142',
          substituteForMember: 'Vishwatmika Jadhav',
          substituteName: 'Alzaba Feroz',
          memberId: 'emp_member',
          photoBase64: 'selfie',
        );
        // Remapped dashboard row: userPhone == member roster phone.
        const covered = Employee(
          id: 'emp_member',
          name: 'Vishwatmika Jadhav',
          phone: '9920734142',
          email: 'v@example.com',
        );
        final displayed = raw.copyWith(
          userName: covered.name,
          userPhone: covered.phone,
          substituteName: 'Alzaba Feroz',
          clearSubstitutePhone: true,
        );

        final fields = resolveSubstituteAttendeeFields(
          displayed: displayed,
          raw: raw.copyWith(clearSubstitutePhone: true),
          coveredMemberName: covered.name,
          coveredMemberPhone: covered.phone,
        );

        expect(fields.name, 'Alzaba Feroz');
        expect(fields.phone, '');
        expect(fields.displayLabel, 'Alzaba Feroz');
      },
    );

    test('prefers dedicated substitutePhone over corrupted userPhone', () {
      final raw = CheckInSubmission(
        id: 'sub-1',
        locationId: 'loc',
        locationName: 'Venue',
        userName: 'Vishwatmika Jadhav',
        userPhone: '9920734142',
        type: CheckInType.substitute,
        userLatitude: 0,
        userLongitude: 0,
        gpsAccuracy: 5,
        distanceMeters: 10,
        timestamp: DateTime(2026, 10, 8, 10, 0),
        substituteForMember: 'Vishwatmika Jadhav',
        substituteName: 'Alzaba Feroz',
        substitutePhone: '9876543210',
        memberId: 'emp_member',
      );
      const covered = Employee(
        id: 'emp_member',
        name: 'Vishwatmika Jadhav',
        phone: '9920734142',
        email: 'v@example.com',
      );

      final fields = resolveSubstituteAttendeeFields(
        displayed: raw,
        raw: raw,
        coveredMemberName: covered.name,
        coveredMemberPhone: covered.phone,
      );

      expect(fields.phone, '9876543210');
      expect(fields.displayLabel, 'Alzaba Feroz');
    });

    test(
      'substituteName set + null substitutePhone → empty phone (UI —)',
      () {
        final raw = CheckInSubmission(
          id: 'sub-2',
          locationId: 'loc',
          locationName: 'Venue',
          userName: 'Vishwatmika Jadhav',
          userPhone: '9920734142',
          type: CheckInType.substitute,
          userLatitude: 0,
          userLongitude: 0,
          gpsAccuracy: 5,
          distanceMeters: 10,
          timestamp: DateTime(2026, 10, 8, 10, 0),
          substituteForMember: 'Vishwatmika Jadhav',
          substituteName: 'Gaurav',
          memberId: 'emp_member',
        );

        final fields = resolveSubstituteAttendeeFields(
          displayed: raw,
          raw: raw,
          coveredMemberName: 'Vishwatmika Jadhav',
          coveredMemberPhone: '9920734142',
        );

        expect(fields.name, 'Gaurav');
        expect(fields.phone, isEmpty);
        expect(fields.displayLabel, 'Gaurav');
      },
    );
  });

  group('toFirestoreMap', () {
    test('omits null optional fields', () {
      final submission = CheckInSubmission(
        id: 'c1',
        locationId: 'location_x',
        locationName: 'Venue',
        userName: 'Omkar',
        userPhone: '9976543215',
        type: CheckInType.absent,
        userLatitude: 0,
        userLongitude: 0,
        gpsAccuracy: 0,
        distanceMeters: 0,
        timestamp: DateTime(2026, 10, 8),
        substituteForMember: null,
        substituteName: null,
        verifiedAt: null,
        verifiedBy: null,
        memberId: 'emp_omkar',
      );

      final map = submission.toFirestoreMap();
      expect(map.containsKey('substituteForMember'), isFalse);
      expect(map.containsKey('substituteName'), isFalse);
      expect(map.containsKey('verifiedAt'), isFalse);
      expect(map.containsKey('memberId'), isTrue);
      expect(map.values.every((v) => v != null), isTrue);
    });
  });
}
