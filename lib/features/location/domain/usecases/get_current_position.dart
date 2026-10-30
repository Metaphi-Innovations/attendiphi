import 'package:geolocator/geolocator.dart';

import '../../data/datasources/location_device_data_source.dart';

/// Usecase to obtain the user's current GPS position.
class GetCurrentPosition {
  const GetCurrentPosition(this._deviceDataSource);

  final LocationDeviceDataSource _deviceDataSource;

  Future<Position> call({
    bool permissionAlreadyGranted = false,
    bool forceRefresh = false,
  }) {
    return _deviceDataSource.getCurrentPosition(
      permissionAlreadyGranted: permissionAlreadyGranted,
      forceRefresh: forceRefresh,
    );
  }
}
