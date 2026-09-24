import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/router/app_url.dart';
import 'package:qr_checkin/app/router/route_names.dart';

void main() {
  test('password reset action handler is the Flutter /admin-reset-password URL',
      () {
    expect(
      AppUrl.passwordResetActionHandler,
      'https://attendiphi-by-metaphi.web.app/admin-reset-password',
    );
    expect(AppUrl.passwordResetActionHandler.contains('/__/auth/action'), isFalse);
  });

  test('both production hosts are recognized', () {
    expect(
      AppUrl.productionOrigins,
      containsAll([
        'https://attendiphi-by-metaphi.web.app',
        'https://attendiphi.metaphi.in',
      ]),
    );
    expect(AppUrl.isAllowedHost('attendiphi-by-metaphi.web.app'), isTrue);
    expect(AppUrl.isAllowedHost('attendiphi.metaphi.in'), isTrue);
  });

  test('detects Firebase resetPassword mode', () {
    expect(AppUrl.isFirebasePasswordResetMode('resetPassword'), isTrue);
    expect(AppUrl.isFirebasePasswordResetMode('recoverEmail'), isFalse);
    expect(AppUrl.isFirebasePasswordResetMode(null), isFalse);
  });

  test('rewrites Firebase hosted oob links onto /admin-reset-password', () {
    const firebaseLink =
        'https://qr-checkin-dev.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=OOB123&apiKey=AIzaPublic&lang=en';
    final landing = AppUrl.flutterResetUrlFromFirebaseOobLink(firebaseLink);
    expect(landing.startsWith(AppUrl.passwordResetActionHandler), isTrue);
    expect(landing.contains('mode=resetPassword'), isTrue);
    expect(landing.contains('oobCode=OOB123'), isTrue);
    expect(landing.contains('apiKey=AIzaPublic'), isTrue);
    expect(landing.contains('/__/auth/action'), isFalse);
  });

  test('password reset landing requires oobCode', () {
    expect(
      () => AppUrl.flutterResetUrlFromFirebaseOobLink(
        'https://qr-checkin-dev.firebaseapp.com/__/auth/action?mode=resetPassword',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('builds public URLs without a hash fragment', () {
    final url = AppUrl.public(
      path: RouteNames.adminMembers,
    );
    expect(url.contains('#'), isFalse);
    expect(url.endsWith('/members'), isTrue);
  });

  test('builds check-in URLs with query parameters and no hash', () {
    final url = AppUrl.public(
      path: RouteNames.locationPermission,
      queryParameters: {
        'date': '2026-09-03',
        'locationId': 'location_x',
      },
    );
    expect(url.contains('#'), isFalse);
    expect(url, contains('/checkin-permission?'));
    expect(url, contains('date=2026-09-03'));
    expect(url, contains('locationId=location_x'));
  });

  test('check-in result path carries memberId instead of a name', () {
    final path = RouteNames.checkinResultPath(
      checkInId: 'sub-1',
      memberId: 'member_omkar',
    );
    expect(path, '/checkin-result?checkInId=sub-1&memberId=member_omkar');
    expect(path.contains('Omkar'), isFalse);
    expect(path.contains('omkaaarr'), isFalse);
  });
}
