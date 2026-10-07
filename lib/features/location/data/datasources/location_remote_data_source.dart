import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../models/location_config_model.dart';

/// Contract for fetching location data directly from Firestore.
abstract class LocationRemoteDataSource {
  Future<LocationConfigModel?> fetchLocation(String locationId);
  Stream<List<LocationConfigModel>> streamLocations();
}

/// Firestore implementation of [LocationRemoteDataSource].
class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  LocationRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<LocationConfigModel?> fetchLocation(String locationId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.locationsCollection)
          .doc(locationId)
          .get();

      if (!doc.exists) {
        // Built-in fallback for location_x (Jade Luxury Banquets, Mumbai)
        if (locationId == 'location_x') {
          return const LocationConfigModel(
            id: 'location_x',
            name: 'Jade Luxury Banquets, Mumbai',
            latitude: 18.9888622,
            longitude: 72.8152475,
            radiusMeters: 500.0,
            isActive: true,
            address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
          );
        }
        return null;
      }

      return LocationConfigModel.fromFirestore(doc);
    } on FirebaseException catch (e, st) {
      AppLogger.warning(
        'Firestore fetchLocation fallback for $locationId: ${e.message}',
        tag: 'LocationRemoteDataSource',
      );
      if (locationId == 'location_x') {
        return const LocationConfigModel(
          id: 'location_x',
          name: 'Jade Luxury Banquets, Mumbai',
          latitude: 18.9888622,
          longitude: 72.8152475,
          radiusMeters: 500.0,
          isActive: true,
          address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
        );
      }
      throw ServerException(
        technicalMessage: 'Firestore error: ${e.code} - ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (locationId == 'location_x') {
        return const LocationConfigModel(
          id: 'location_x',
          name: 'Jade Luxury Banquets, Mumbai',
          latitude: 18.9888622,
          longitude: 72.8152475,
          radiusMeters: 500.0,
          isActive: true,
          address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
        );
      }
      throw ServerException(
        technicalMessage: 'Unexpected error fetching location: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<List<LocationConfigModel>> streamLocations() {
    return _firestore
        .collection(AppConstants.locationsCollection)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(LocationConfigModel.fromFirestore).toList();
        });
  }
}
