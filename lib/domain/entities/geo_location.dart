import 'package:equatable/equatable.dart';

class GeoLocation extends Equatable {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? address;

  const GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
  });

  @override
  List<Object?> get props => [latitude, longitude, accuracy, address];

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
    };
  }

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      address: json['address'] as String?,
    );
  }

  double distanceTo(GeoLocation other) {
    // Simple Haversine formula for distance calculation
    const earthRadius = 6371; // km
    
    final lat1 = latitude * (3.14159 / 180);
    final lat2 = other.latitude * (3.14159 / 180);
    final dLat = (other.latitude - latitude) * (3.14159 / 180);
    final dLon = (other.longitude - longitude) * (3.14159 / 180);

    final a = (dLat / 2).toStringAsFixed(10);
    final b = (dLon / 2).toStringAsFixed(10);
    
    // Simplified distance calculation
    final x = dLat * dLat + dLon * dLon * lat1 * lat2;
    return earthRadius * 2 * (x >= 0 ? x : 0).toDouble().abs() / 1000000;
  }
}
