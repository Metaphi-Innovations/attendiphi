import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/location_config.dart';

/// Data model for serializing and deserializing location configuration
/// to and from plain maps (Supabase rows / JSON).
class LocationConfigModel extends LocationConfig {
  const LocationConfigModel({
    required super.id,
    required super.name,
    required super.latitude,
    required super.longitude,
    super.radiusMeters = AppConstants.defaultRadiusMeters,
    super.isActive = true,
    super.address,
  });

  /// Factory constructor to deserialize from a raw Map with an ID.
  factory LocationConfigModel.fromMap(String id, Map<String, dynamic> map) {
    return LocationConfigModel(
      id: id,
      name: map['name']?.toString() ?? 'Unnamed Location',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      radiusMeters: _parseDouble(
        map['radiusMeters'],
        fallback: AppConstants.defaultRadiusMeters,
      ),
      isActive: map['isActive'] as bool? ?? true,
      address: map['address']?.toString(),
    );
  }

  /// Serializes the model to a plain Map.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'isActive': isActive,
      'address': address,
    };
  }

  static double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
