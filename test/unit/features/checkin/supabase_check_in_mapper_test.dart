import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/checkin/data/mappers/supabase_check_in_mapper.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';

void main() {
  group('SupabaseCheckInMapper.listSelect', () {
    test('excludes photo_base64 and includes photo_path + has_photo', () {
      expect(
        SupabaseCheckInMapper.listSelect.contains('photo_base64'),
        isFalse,
      );
      expect(SupabaseCheckInMapper.listSelect.contains('photo_path'), isTrue);
      expect(SupabaseCheckInMapper.listSelect.contains('has_photo'), isTrue);
    });
  });

  group('SupabaseCheckInMapper.toRow', () {
    test('writes photo_path / has_photo and omits photo_base64', () {
      final row = SupabaseCheckInMapper.toRow(
        CheckInSubmission(
          id: 'c1',
          locationId: 'location_x',
          locationName: 'Jade',
          userName: 'Sub',
          userPhone: '+919876543210',
          type: CheckInType.substitute,
          userLatitude: 1,
          userLongitude: 2,
          gpsAccuracy: 3,
          distanceMeters: 4,
          timestamp: DateTime.utc(2026, 10, 15, 8),
          photoBase64: '/9j/legacy',
          photoPath: '2026-10-15/c1.jpg',
          hasPhoto: true,
        ),
      );
      expect(row.containsKey('photo_base64'), isFalse);
      expect(row['photo_path'], '2026-10-15/c1.jpg');
      expect(row['has_photo'], isTrue);
    });
  });

  group('SupabaseCheckInMapper.fromRow', () {
    test('maps photo_path and has_photo from lean list row', () {
      final submission = SupabaseCheckInMapper.fromRow({
        'id': 'c1',
        'type': 'substitute',
        'location_id': 'location_x',
        'location_name': 'Jade',
        'user_name': 'Sub',
        'user_phone': '+919876543210',
        'user_latitude': 1,
        'user_longitude': 2,
        'gps_accuracy': 3,
        'distance_meters': 4,
        'timestamp': '2026-10-15T08:00:00Z',
        'photo_path': '2026-10-15/c1.jpg',
        'has_photo': true,
      });
      expect(submission.photoPath, '2026-10-15/c1.jpg');
      expect(submission.hasPhoto, isTrue);
      expect(submission.photoBase64, isNull);
    });
  });
}
