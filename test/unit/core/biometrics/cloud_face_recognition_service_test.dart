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
      expect(result.errorMessage, contains('Server face check unavailable (500)'));
    });

    test('Matches enrolled member when live selfie is mirrored and brighter', () async {
      img.Image buildFace({required int brightnessOffset}) {
        final imgObj = img.Image(width: 96, height: 96);
        final skin = img.ColorRgb8(
          (180 + brightnessOffset).clamp(0, 255),
          (140 + brightnessOffset).clamp(0, 255),
          (120 + brightnessOffset).clamp(0, 255),
        );
        img.fill(imgObj, color: skin);
        img.fillRect(imgObj, x1: 26, y1: 32, x2: 36, y2: 38, color: img.ColorRgb8(40, 30, 30));
        img.fillRect(imgObj, x1: 60, y1: 32, x2: 70, y2: 38, color: img.ColorRgb8(40, 30, 30));
        img.fillRect(imgObj, x1: 44, y1: 44, x2: 52, y2: 56, color: img.ColorRgb8(150, 110, 90));
        img.fillRect(imgObj, x1: 34, y1: 64, x2: 62, y2: 70, color: img.ColorRgb8(160, 70, 70));
        return imgObj;
      }

      final enrolled = buildFace(brightnessOffset: 0);
      final live = img.flipHorizontal(buildFace(brightnessOffset: 35));

      final enrolledB64 = base64Encode(Uint8List.fromList(img.encodeJpg(enrolled)));
      final liveB64 = base64Encode(Uint8List.fromList(img.encodeJpg(live)));

      final rinku = Employee(
        id: 'emp_rinku',
        name: 'Rinku Saroj',
        phone: '7303469139',
        photoUrl: enrolledB64,
      );

      final service = CloudFaceRecognitionService();
      final result = await service.matchFace(
        photoBase64: liveB64,
        candidates: [rinku],
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedMember?.id, equals('emp_rinku'));
    });

    test('Matches candidate via enrolled profile photo without server call', () async {
      final imgObj = img.Image(width: 64, height: 64);
      img.fill(imgObj, color: img.ColorRgb8(200, 160, 140));
      // Draw facial features (eyes, nose, mouth)
      img.fillRect(imgObj, x1: 18, y1: 22, x2: 26, y2: 26, color: img.ColorRgb8(40, 30, 30));
      img.fillRect(imgObj, x1: 38, y1: 22, x2: 46, y2: 26, color: img.ColorRgb8(40, 30, 30));
      img.fillRect(imgObj, x1: 30, y1: 32, x2: 34, y2: 40, color: img.ColorRgb8(160, 120, 100));
      img.fillRect(imgObj, x1: 22, y1: 46, x2: 42, y2: 50, color: img.ColorRgb8(180, 80, 80));

      final jpgBytes = Uint8List.fromList(img.encodeJpg(imgObj));
      final base64Photo = base64Encode(jpgBytes);

      final candidateWithPhoto = Employee(
        id: 'emp_201',
        name: 'omkaarrr',
        phone: '8356011246',
        photoUrl: base64Photo,
      );

      final service = CloudFaceRecognitionService();
      final result = await service.matchFace(
        photoBase64: base64Photo,
        candidates: [candidateWithPhoto],
      );

      expect(result.isMatch, isTrue);
      expect(result.matchedMember?.id, equals('emp_201'));
      expect(result.matchedMember?.name, equals('omkaarrr'));
      expect(result.confidence, greaterThanOrEqualTo(80.0));
    });

    test('Returns isMatch = false when non-member photo is captured even if chapter has only one enrolled member', () async {
      // Member photo: Dark toned image
      final memberImg = img.Image(width: 64, height: 64);
      img.fill(memberImg, color: img.ColorRgb8(30, 30, 40));
      final memberJpg = Uint8List.fromList(img.encodeJpg(memberImg));
      final memberPhotoBase64 = base64Encode(memberJpg);

      // Non-member photo: Bright yellow/green image (completely different)
      final nonMemberImg = img.Image(width: 64, height: 64);
      img.fill(nonMemberImg, color: img.ColorRgb8(240, 220, 50));
      final nonMemberJpg = Uint8List.fromList(img.encodeJpg(nonMemberImg));
      final nonMemberPhotoBase64 = base64Encode(nonMemberJpg);

      final singleEnrolledMember = Employee(
        id: 'emp_rinku',
        name: 'Rinku Saroj',
        phone: '7303469139',
        photoUrl: memberPhotoBase64,
      );

      final service = CloudFaceRecognitionService();
      final result = await service.matchFace(
        photoBase64: nonMemberPhotoBase64,
        candidates: [singleEnrolledMember],
      );

      expect(result.isMatch, isFalse);
      expect(result.matchedMember, isNull);
    });

    test('Strictly rejects non-member face when compared to enrolled Rinku Saroj face', () async {
      final rinkuImg = img.Image(width: 96, height: 96);
      img.fill(rinkuImg, color: img.ColorRgb8(210, 175, 150));
      img.fillRect(rinkuImg, x1: 18, y1: 8, x2: 78, y2: 28, color: img.ColorRgb8(40, 28, 20));
      img.fillRect(rinkuImg, x1: 28, y1: 34, x2: 40, y2: 42, color: img.ColorRgb8(30, 20, 20));
      img.fillRect(rinkuImg, x1: 56, y1: 34, x2: 68, y2: 42, color: img.ColorRgb8(30, 20, 20));
      img.fillRect(rinkuImg, x1: 44, y1: 46, x2: 52, y2: 60, color: img.ColorRgb8(150, 110, 90));
      img.fillRect(rinkuImg, x1: 34, y1: 68, x2: 62, y2: 76, color: img.ColorRgb8(170, 70, 70));

      final rinkuBytes = Uint8List.fromList(img.encodeJpg(rinkuImg));
      final rinkuBase64 = base64Encode(rinkuBytes);

      final visitorImg = img.Image(width: 96, height: 96);
      img.fill(visitorImg, color: img.ColorRgb8(90, 130, 170));
      img.fillRect(visitorImg, x1: 10, y1: 4, x2: 86, y2: 22, color: img.ColorRgb8(220, 220, 230));
      img.fillRect(visitorImg, x1: 12, y1: 48, x2: 28, y2: 56, color: img.ColorRgb8(20, 20, 20));
      img.fillRect(visitorImg, x1: 68, y1: 48, x2: 84, y2: 56, color: img.ColorRgb8(20, 20, 20));
      img.fillRect(visitorImg, x1: 42, y1: 58, x2: 54, y2: 70, color: img.ColorRgb8(120, 80, 60));
      img.fillRect(visitorImg, x1: 20, y1: 76, x2: 76, y2: 90, color: img.ColorRgb8(40, 30, 30));

      final visitorBytes = Uint8List.fromList(img.encodeJpg(visitorImg));
      final visitorBase64 = base64Encode(visitorBytes);

      final rinkuMember = Employee(
        id: 'emp_rinku',
        name: 'Rinku Saroj',
        phone: '7303469139',
        photoUrl: rinkuBase64,
      );

      final service = CloudFaceRecognitionService();
      final result = await service.matchFace(
        photoBase64: visitorBase64,
        candidates: [rinkuMember],
      );

      // Must be unrecognized!
      expect(result.isMatch, isFalse);
      expect(result.matchedMember, isNull);
      expect(result.errorMessage, equals('Face not recognized in this chapter.'));
    });
  });
}

