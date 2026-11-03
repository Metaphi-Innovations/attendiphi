import '../../../../core/constants/app_constants.dart';

/// Domain entity representing a configured check-in location from Firestore.
class LocationConfig {
  const LocationConfig({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = AppConstants.defaultRadiusMeters,
    this.isActive = true,
    this.address,
  });

  /// Unique Firestore document ID for this location (e.g. "location_x").
  final String id;

  /// Human-readable name of the location (e.g. "Headquarters", "Mumbai Hub").
  final String name;

  /// Latitude coordinate of the official check-in point.
  final double latitude;

  /// Longitude coordinate of the official check-in point.
  final double longitude;

  /// Configurable allowed radius in meters (default 500m).
  final double radiusMeters;

  /// Whether this location is currently accepting check-ins.
  final bool isActive;

  /// Optional physical address for display.
  final String? address;

  LocationConfig copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isActive,
    String? address,
  }) {
    return LocationConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isActive: isActive ?? this.isActive,
      address: address ?? this.address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationConfig &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          radiusMeters == other.radiusMeters;

  @override
  int get hashCode => Object.hash(id, radiusMeters);

  @override
  String toString() =>
      'LocationConfig(id: $id, name: $name, lat: $latitude, lon: $longitude, radius: ${radiusMeters}m, isActive: $isActive)';
}
