import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/router/app_url.dart';
import 'package:qr_checkin/app/router/route_names.dart';

void main() {
  test('password reset action handler uses branded production origin', () {
    expect(
      AppUrl.passwordResetActionHandler,
      'https://attendiphi.metaphi.in/admin-reset-password',
    );
    expect(
      AppUrl.passwordResetActionHandler.contains('/__/auth/action'),
      isFalse,
    );
  });

  test('production origin and allowed hosts', () {
    expect(AppUrl.productionOrigin, 'https://attendiphi.metaphi.in');
    expect(
      AppUrl.productionOrigins,
      containsAll([
        'https://attendiphi.metaphi.in',
        'http://localhost',
        'http://127.0.0.1',
      ]),
    );
    expect(AppUrl.isAllowedHost('attendiphi.metaphi.in'), isTrue);
    expect(AppUrl.isAllowedHost('attendiphi-by-metaphi.web.app'), isFalse);
  });

  test('passwordResetLanding builds query on admin-reset-password', () {
    final landing = AppUrl.passwordResetLanding(
      oobCode: 'OOB123',
      apiKey: 'public-anon',
    );
    expect(landing.startsWith(AppUrl.passwordResetActionHandler), isTrue);
    expect(landing.contains('oobCode=OOB123'), isTrue);
    expect(landing.contains('apiKey=public-anon'), isTrue);
    expect(landing.contains('/__/auth/action'), isFalse);
  });

  test('checkInPublic always uses production origin', () {
    final url = AppUrl.checkInPublic(
      path: RouteNames.locationPermission,
      queryParameters: {'date': '2026-09-03', 'locationId': 'location_x'},
    );
    expect(url.startsWith('https://attendiphi.metaphi.in'), isTrue);
    expect(url.contains('#'), isFalse);
    expect(url, contains('/checkin-permission?'));
    expect(url, contains('date=2026-09-03'));
    expect(url, contains('locationId=location_x'));
  });

  test('builds public URLs without a hash fragment', () {
    final url = AppUrl.public(path: RouteNames.adminMembers);
    expect(url.contains('#'), isFalse);
    expect(url.endsWith('/members'), isTrue);
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
