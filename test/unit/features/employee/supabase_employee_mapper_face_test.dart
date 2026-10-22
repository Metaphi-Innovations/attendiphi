import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/employee/data/datasources/supabase_employee_mapper.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  group('SupabaseEmployeeMapper face candidates', () {
    test('fromFaceCandidateRow builds SFace templates from embedding + raw', () {
      final employee = SupabaseEmployeeMapper.fromFaceCandidateRow({
        'member_id': 'm1',
        'name': 'omkar',
        'phone': '8356011246',
        'is_active': true,
        'model': 'sface',
        'model_version': '2021dec',
        'embedding': List<double>.filled(128, 0.1),
        'raw': {
          'faceTemplates': [
            List<double>.filled(128, 0.1),
            List<double>.filled(128, 0.2),
          ],
        },
      });

      expect(employee.id, 'm1');
      expect(employee.name, 'omkar');
      expect(employee.hasSfaceTemplates, isTrue);
      expect(employee.sfaceTemplates.length, 2);
      expect(employee.faceEnrolled, isTrue);
    });

    test('withFaceTemplates merges onto roster member', () {
      const base = Employee(
        id: 'm1',
        name: 'omkar',
        phone: '8356011246',
        isActive: true,
      );
      final enriched = SupabaseEmployeeMapper.withFaceTemplates(base, {
        'embedding': List<double>.filled(128, 0.5),
        'raw': {
          'faceTemplates': [List<double>.filled(128, 0.5)],
        },
        'model': 'sface',
        'model_version': '2021dec',
      });

      expect(enriched.hasSfaceTemplates, isTrue);
      expect(enriched.faceModel, 'sface');
      expect(enriched.name, 'omkar');
    });
  });
}
