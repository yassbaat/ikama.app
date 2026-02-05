import 'package:equatable/equatable.dart';
import 'prayer_times.dart';

class Mosque extends Equatable {
  final String id;
  final String name;
  final String? address;
  final String? city;
  final String? country;
  final double? latitude;
  final double? longitude;
  final bool isFavorite;
  final DateTime? lastAccessed;

  const Mosque({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.country,
    this.latitude,
    this.longitude,
    this.isFavorite = false,
    this.lastAccessed,
  });

  Mosque copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    bool? isFavorite,
    DateTime? lastAccessed,
  }) {
    return Mosque(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isFavorite: isFavorite ?? this.isFavorite,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }

  @override
  List<Object?> get props => [
    id, name, address, city, country,
    latitude, longitude, isFavorite, lastAccessed,
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'isFavorite': isFavorite,
      'lastAccessed': lastAccessed?.toIso8601String(),
    };
  }

  factory Mosque.fromJson(Map<String, dynamic> json) {
    return Mosque(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      isFavorite: json['isFavorite'] as bool? ?? false,
      lastAccessed: json['lastAccessed'] != null 
        ? DateTime.parse(json['lastAccessed'] as String) 
        : null,
    );
  }
}
