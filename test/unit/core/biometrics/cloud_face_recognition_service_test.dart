import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:qr_checkin/core/biometrics/cloud_face_recognition_service.dart';
import 'package:qr_checkin/core/biometrics/face_matching_service.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  group('CloudFaceRecognitionService', () {
    final candidate1 = Employee(
      id: 'emp_101',
      name: 'Omkar Anarse',
      phone: '9876543210',
      faceEmbedding: List.filled(192, 0.05),
    );

    final candidate2 = Employee(
      id: 'emp_102',
      name: 'John Doe',
      phone: '9876543211',
      faceEmbedding: List.filled(192, 0.5),
    );

    final candidates = [candidate1, candidate2];

    test('Returns isMatch = false when candidates have no face embeddings', () async {
      final service = CloudFaceRecognitionService();
      const memberWithoutEmbedding = Employee(
        id: 'emp_999',
        name: 'No Biometric',
        phone: '1234567890',
      );

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: [memberWithoutEmbedding],
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, contains('Face not recognized in this chapter'));
    });

    test('Successfully parses direct match from cloud response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'matched': true,
            'memberId': 'emp_101',
            'confidence': 96.5,
          }),
          200,
        );
      });

      final service = CloudFaceRecognitionService(httpClient: mockClient);

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedMember?.id, equals('emp_101'));
      expect(result.matchedMember?.name, equals('Omkar Anarse'));
      expect(result.confidence, equals(96.5));
    });

    test('Verifies probe embedding locally when returned by cloud', () async {
      // Mock cloud function returning an embedding vector close to candidate1
      final probeEmbedding = List.filled(192, 0.05);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'matched': false,
            'embedding': probeEmbedding,
          }),
          200,
        );
      });

      final service = CloudFaceRecognitionService(
        httpClient: mockClient,
        matchingService: FaceMatchingService(),
      );

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedMember?.id, equals('emp_101'));
      expect(result.confidence, closeTo(100.0, 0.1));
    });

    test('Gracefully returns isMatch = false on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = CloudFaceRecognitionService(httpClient: mockClient);

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, contains('Face not recognized in this chapter'));
    });

    test('Rejects match when cloud function reports no match and returns no embedding', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'matched': false,
            'message': 'Face not recognized with sufficient confidence in this chapter.',
          }),
          200,
        );
      });

      final service = CloudFaceRecognitionService(httpClient: mockClient);

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isFalse);
      expect(result.matchedMember, isNull);
    });

    test('Rejects match when candidate list is empty', () async {
      final service = CloudFaceRecognitionService();

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: [],
      );

      expect(result.isMatch, isFalse);
      expect(result.matchedMember, isNull);
    });

    test('Verify API endpoint handles quality failure gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'matched': false,
            'face_detected': false,
            'reason': 'NO_FACE_DETECTED',
          }),
          200,
        );
      });

      final service = CloudFaceRecognitionService(
        httpClient: mockClient,
        apiBaseUrl: 'https://face.test',
      );

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, contains('No face detected'));
    });

    test('Matches Omkar selfie to his enrolled photo when neural API is offline', () async {
      img.Image buildOmkar() {
        final imgObj = img.Image(width: 96, height: 96);
        img.fill(imgObj, color: img.ColorRgb8(90, 70, 55));
        img.fillRect(imgObj, x1: 8, y1: 6, x2: 88, y2: 22, color: img.ColorRgb8(20, 16, 12));
        img.fillRect(imgObj, x1: 22, y1: 40, x2: 34, y2: 50, color: img.ColorRgb8(15, 10, 10));
        img.fillRect(imgObj, x1: 62, y1: 40, x2: 74, y2: 50, color: img.ColorRgb8(15, 10, 10));
        img.fillRect(imgObj, x1: 44, y1: 52, x2: 54, y2: 68, color: img.ColorRgb8(80, 55, 40));
        img.fillRect(imgObj, x1: 30, y1: 74, x2: 66, y2: 84, color: img.ColorRgb8(50, 30, 25));
        return imgObj;
      }

      img.Image buildRinku() {
        final imgObj = img.Image(width: 96, height: 96);
        img.fill(imgObj, color: img.ColorRgb8(210, 170, 140));
        img.fillRect(imgObj, x1: 18, y1: 8, x2: 78, y2: 28, color: img.ColorRgb8(40, 28, 20));
        img.fillRect(imgObj, x1: 28, y1: 34, x2: 40, y2: 42, color: img.ColorRgb8(30, 20, 20));
        img.fillRect(imgObj, x1: 56, y1: 34, x2: 68, y2: 42, color: img.ColorRgb8(30, 20, 20));
        img.fillRect(imgObj, x1: 44, y1: 46, x2: 52, y2: 60, color: img.ColorRgb8(150, 110, 90));
        img.fillRect(imgObj, x1: 34, y1: 68, x2: 62, y2: 76, color: img.ColorRgb8(170, 70, 70));
        return imgObj;
      }

      final omkarPhoto = base64Encode(Uint8List.fromList(img.encodeJpg(buildOmkar())));
      final rinkuPhoto = base64Encode(Uint8List.fromList(img.encodeJpg(buildRinku())));
      final omkarSelfie = base64Encode(
        Uint8List.fromList(img.encodeJpg(img.flipHorizontal(buildOmkar()))),
      );

      final service = CloudFaceRecognitionService();
      final result = await service.matchFace(
        photoBase64: omkarSelfie,
        candidates: [
          Employee(
            id: 'emp_rinku',
            name: 'Rinku Saroj',
            phone: '7303469139',
            photoUrl: rinkuPhoto,
          ),
          Employee(
            id: 'emp_omkar',
            name: 'Omkar Anarse',
            phone: '8356011246',
            photoUrl: omkarPhoto,
          ),
        ],
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedMember?.id, equals('emp_omkar'));
    });
  });
}
