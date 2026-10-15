import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/substitutes_analytics.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

CheckInSubmission _sub({
  required String id,
  required String substituteName,
  required String substitutePhone,
  required String forMember,
  String? memberId,
  required DateTime at,
  String? photo,
  String? photoPath,
}) {
  return CheckInSubmission(
    id: id,
    locationId: 'loc',
    locationName: 'Venue',
    userName: forMember,
    userPhone: substitutePhone,
    type: CheckInType.substitute,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 0,
    distanceMeters: 0,
    timestamp: at,
    substituteForMember: forMember,
    substituteName: substituteName,
    substitutePhone: substitutePhone,
    memberId: memberId,
    photoBase64: photo,
    photoPath: photoPath,
    hasPhoto: (photo != null && photo.isNotEmpty) ||
        (photoPath != null && photoPath.isNotEmpty),
  );
}

void main() {
  const personA = Employee(id: 'emp_a', name: 'Person A', phone: '9000000001');
  const personB = Employee(id: 'emp_b', name: 'Person B', phone: '9000000002');
  const personC = Employee(id: 'emp_c', name: 'Person C', phone: '9000000003');

  group('formatSubstitutePhoneDisplay', () {
    test('normalizes bare and +91 phones to spaced 10 digits (no country code)', () {
      expect(formatSubstitutePhoneDisplay('9920734142'), '99207 34142');
      expect(formatSubstitutePhoneDisplay('+917900128501'), '79001 28501');
      expect(formatSubstitutePhoneDisplay('+91 98765 43210'), '98765 43210');
    });
  });

  group('substituteIdentityKey', () {
    test('uses phone+name composite, never phone alone', () {
      expect(
        substituteIdentityKey(
          phone: '+91 98765 43210',
          displayName: 'Omkar',
          fallbackRecordId: 'x',
        ),
        'pn:9876543210:omkar',
      );
    });

    test('falls back to check-in id then name', () {
      expect(
        substituteIdentityKey(
          phone: '',
          displayName: 'Omkar Anarse',
          fallbackRecordId: 'c1',
        ),
        'c:c1',
      );
      expect(
        substituteIdentityKey(
          phone: '',
          displayName: '',
          fallbackRecordId: 'c1',
        ),
        'c:c1',
      );
    });
  });

  group('2-of-3 identity matching', () {
    test('same phone different name+photo → 2 profiles (Gaurav/Alzaba)', () {
      final analytics = buildSubstitutesAnalytics(
        checkIns: [
          _sub(
            id: 'gaurav',
            substituteName: 'Gaurav',
            substitutePhone: '9920734142',
            forMember: 'Person A',
            at: DateTime(2026, 10, 8, 7, 50),
            photo: 'photo_gaurav_bytes',
            photoPath: '2026-10-08/gaurav.jpg',
          ),
          _sub(
            id: '0540dedf-a713-49ea-a102-27350a181d3a',
            substituteName: 'Alzaba Feroz',
            substitutePhone: '9920734142',
            forMember: 'Vishwatmika Jadhav',
            at: DateTime(2026, 10, 8, 7, 56),
            photo: 'photo_alzaba_bytes',
            photoPath: '2026-10-08/alzaba.jpg',
          ),
        ],
      );
      expect(analytics.summary.uniqueSubstitutes, 2);
      expect(analytics.summary.totalVisits, 2);
      final names = analytics.profiles.map((p) => p.displayName).toSet();
      expect(names, containsAll(['Gaurav', 'Alzaba Feroz']));
      for (final p in analytics.profiles) {
        expect(p.phoneDisplay, '99207 34142');
      }
    });

    test('same phone+name missing photo → merge', () {
      final analytics = buildSubstitutesAnalytics(
        checkIns: [
          _sub(
            id: '1',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person A',
            at: DateTime(2026, 10, 1),
          ),
          _sub(
            id: '2',
            substituteName: 'Omkar Anarse',
            substitutePhone: '+919876543210',
            forMember: 'Person B',
            at: DateTime(2026, 10, 2),
          ),
        ],
      );
      expect(analytics.summary.uniqueSubstitutes, 1);
      expect(analytics.summary.totalVisits, 2);
      expect(analytics.profiles.single.phoneDisplay, '98765 43210');
    });

    test('same name different phones+photos → 2 profiles (Asrar)', () {
      final analytics = buildSubstitutesAnalytics(
        checkIns: [
          _sub(
            id: '1',
            substituteName: 'Asrar Ahmed Ansari',
            substitutePhone: '+919326440158',
            forMember: 'Person A',
            at: DateTime(2026, 10, 1),
            photoPath: 'a.jpg',
          ),
          _sub(
            id: '2',
            substituteName: 'Asrar Ansari',
            substitutePhone: '9967533315',
            forMember: 'Person B',
            at: DateTime(2026, 10, 2),
            photoPath: 'b.jpg',
          ),
        ],
      );
      expect(analytics.summary.uniqueSubstitutes, 2);
      expect(analytics.summary.totalVisits, 2);
    });

    test('phone-like name shows Unknown substitute', () {
      final analytics = buildSubstitutesAnalytics(
        checkIns: [
          _sub(
            id: '1',
            substituteName: '7043297313',
            substitutePhone: '7043297313',
            forMember: 'Person A',
            at: DateTime(2026, 10, 1),
          ),
        ],
      );
      expect(analytics.profiles.single.displayName, 'Unknown substitute');
      expect(analytics.profiles.single.phoneDisplay, '70432 97313');
    });

    test('same phone+photo different names → merge (2 signals)', () {
      final analytics = buildSubstitutesAnalytics(
        checkIns: [
          _sub(
            id: '1',
            substituteName: 'Person One',
            substitutePhone: '9920734142',
            forMember: 'Person A',
            at: DateTime(2026, 10, 8),
            photoPath: 'same.jpg',
          ),
          _sub(
            id: '2',
            substituteName: 'Totally Different',
            substitutePhone: '9920734142',
            forMember: 'Person A',
            at: DateTime(2026, 10, 15),
            photoPath: 'same.jpg',
          ),
        ],
      );
      expect(analytics.summary.uniqueSubstitutes, 1);
      expect(analytics.summary.totalVisits, 2);
    });
  });

  group('buildSubstitutesAnalytics', () {
    test('groups Omkar visits by member with matching totals', () {
      final analytics = buildSubstitutesAnalytics(
        employees: const [personA, personB, personC],
        checkIns: [
          _sub(
            id: '1',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person A',
            memberId: 'emp_a',
            at: DateTime(2026, 10, 1),
          ),
          _sub(
            id: '2',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person A',
            memberId: 'emp_a',
            at: DateTime(2026, 10, 5),
          ),
          _sub(
            id: '3',
            substituteName: 'Omkar',
            substitutePhone: '+919876543210',
            forMember: 'Person A',
            memberId: 'emp_a',
            at: DateTime(2026, 10, 10),
          ),
          _sub(
            id: '4',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person A',
            memberId: 'emp_a',
            at: DateTime(2026, 10, 12),
          ),
          _sub(
            id: '5',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person B',
            memberId: 'emp_b',
            at: DateTime(2026, 10, 2),
          ),
          _sub(
            id: '6',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person B',
            memberId: 'emp_b',
            at: DateTime(2026, 10, 8),
          ),
          _sub(
            id: '7',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person B',
            memberId: 'emp_b',
            at: DateTime(2026, 10, 11),
          ),
          _sub(
            id: '8',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person C',
            memberId: 'emp_c',
            at: DateTime(2026, 10, 3),
          ),
          _sub(
            id: '9',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person C',
            memberId: 'emp_c',
            at: DateTime(2026, 10, 6),
          ),
          _sub(
            id: '10',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person C',
            memberId: 'emp_c',
            at: DateTime(2026, 10, 13),
          ),
          _sub(
            id: '10',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person C',
            memberId: 'emp_c',
            at: DateTime(2026, 10, 13),
          ),
          CheckInSubmission(
            id: 'm1',
            locationId: 'loc',
            locationName: 'Venue',
            userName: 'Person A',
            userPhone: '9000000001',
            type: CheckInType.member,
            userLatitude: 0,
            userLongitude: 0,
            gpsAccuracy: 0,
            distanceMeters: 0,
            timestamp: DateTime(2026, 10, 4),
          ),
        ],
      );

      // Phone + strong name similarity (Omkar ⊂ Omkar Anarse) → one profile.
      expect(analytics.summary.uniqueSubstitutes, 1);
      expect(analytics.summary.totalVisits, 10);
      expect(analytics.summary.membersCovered, 3);
      expect(analytics.summary.mostFrequent?.displayName, contains('Omkar'));

      final omkar = analytics.profiles.single;
      expect(omkar.totalVisits, 10);
      expect(omkar.uniqueMembersCovered, 3);
      expect(omkar.phoneDisplay, '98765 43210');
      expect(
        omkar.memberGroups.fold<int>(0, (s, g) => s + g.visitCount),
        omkar.totalVisits,
      );

      final byName = {
        for (final g in omkar.memberGroups) g.memberDisplayName: g.visitCount,
      };
      expect(byName['Person A'], 4);
      expect(byName['Person B'], 3);
      expect(byName['Person C'], 3);
    });

    test('does not merge different phones with same name', () {
      final analytics = buildSubstitutesAnalytics(
        checkIns: [
          _sub(
            id: '1',
            substituteName: 'Same Name',
            substitutePhone: '1111111111',
            forMember: 'Person A',
            at: DateTime(2026, 10, 1),
          ),
          _sub(
            id: '2',
            substituteName: 'Same Name',
            substitutePhone: '2222222222',
            forMember: 'Person A',
            at: DateTime(2026, 10, 2),
          ),
        ],
      );
      // Name only (1 signal) — no merge without phone or photo.
      expect(analytics.summary.uniqueSubstitutes, 2);
      expect(analytics.summary.totalVisits, 2);
    });
  });

  group('filterAndSortSubstituteProfiles', () {
    test('search matches phone and member name partially', () {
      final analytics = buildSubstitutesAnalytics(
        employees: const [personA],
        checkIns: [
          _sub(
            id: '1',
            substituteName: 'Omkar Anarse',
            substitutePhone: '9876543210',
            forMember: 'Person A',
            memberId: 'emp_a',
            at: DateTime(2026, 10, 1),
          ),
        ],
      );

      expect(
        filterAndSortSubstituteProfiles(
          profiles: analytics.profiles,
          searchQuery: '76543',
        ),
        hasLength(1),
      );
      expect(
        filterAndSortSubstituteProfiles(
          profiles: analytics.profiles,
          searchQuery: 'person a',
        ),
        hasLength(1),
      );
      expect(
        filterAndSortSubstituteProfiles(
          profiles: analytics.profiles,
          searchQuery: 'nobody',
        ),
        isEmpty,
      );
    });
  });
}
