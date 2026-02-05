import 'package:equatable/equatable.dart';

class Prayer extends Equatable {
  final String name;
  final DateTime adhan;
  final DateTime? iqama;
  final int? customRakahCount;

  const Prayer({
    required this.name,
    required this.adhan,
    this.iqama,
    this.customRakahCount,
  });

  bool get hasIqama => iqama != null;

  int getRakahCount(Map<String, int> defaults) {
    return customRakahCount ?? defaults[name] ?? 4;
  }

  Prayer copyWith({
    String? name,
    DateTime? adhan,
    DateTime? iqama,
    int? customRakahCount,
  }) {
    return Prayer(
      name: name ?? this.name,
      adhan: adhan ?? this.adhan,
      iqama: iqama ?? this.iqama,
      customRakahCount: customRakahCount ?? this.customRakahCount,
    );
  }

  @override
  List<Object?> get props => [name, adhan, iqama, customRakahCount];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'adhan': adhan.toIso8601String(),
      'iqama': iqama?.toIso8601String(),
      'customRakahCount': customRakahCount,
    };
  }

  factory Prayer.fromJson(Map<String, dynamic> json) {
    return Prayer(
      name: json['name'] as String,
      adhan: DateTime.parse(json['adhan'] as String),
      iqama: json['iqama'] != null 
        ? DateTime.parse(json['iqama'] as String) 
        : null,
      customRakahCount: json['customRakahCount'] as int?,
    );
  }
}

class PrayerTimes extends Equatable {
  final DateTime date;
  final Prayer fajr;
  final Prayer dhuhr;
  final Prayer asr;
  final Prayer maghrib;
  final Prayer isha;
  final Prayer? jumuah;
  final String? mosqueId;
  final DateTime? cachedAt;

  const PrayerTimes({
    required this.date,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.jumuah,
    this.mosqueId,
    this.cachedAt,
  });

  List<Prayer> get allPrayers => [fajr, dhuhr, asr, maghrib, isha];

  Prayer? getPrayerByName(String name) {
    switch (name) {
      case 'Fajr': return fajr;
      case 'Dhuhr': return dhuhr;
      case 'Asr': return asr;
      case 'Maghrib': return maghrib;
      case 'Isha': return isha;
      case 'Jumuah': return jumuah;
      default: return null;
    }
  }

  PrayerTimes copyWith({
    DateTime? date,
    Prayer? fajr,
    Prayer? dhuhr,
    Prayer? asr,
    Prayer? maghrib,
    Prayer? isha,
    Prayer? jumuah,
    String? mosqueId,
    DateTime? cachedAt,
  }) {
    return PrayerTimes(
      date: date ?? this.date,
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      jumuah: jumuah ?? this.jumuah,
      mosqueId: mosqueId ?? this.mosqueId,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  List<Object?> get props => [
    date, fajr, dhuhr, asr, maghrib, isha, 
    jumuah, mosqueId, cachedAt,
  ];

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'fajr': fajr.toJson(),
      'dhuhr': dhuhr.toJson(),
      'asr': asr.toJson(),
      'maghrib': maghrib.toJson(),
      'isha': isha.toJson(),
      'jumuah': jumuah?.toJson(),
      'mosqueId': mosqueId,
      'cachedAt': cachedAt?.toIso8601String(),
    };
  }

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    return PrayerTimes(
      date: DateTime.parse(json['date'] as String),
      fajr: Prayer.fromJson(json['fajr'] as Map<String, dynamic>),
      dhuhr: Prayer.fromJson(json['dhuhr'] as Map<String, dynamic>),
      asr: Prayer.fromJson(json['asr'] as Map<String, dynamic>),
      maghrib: Prayer.fromJson(json['maghrib'] as Map<String, dynamic>),
      isha: Prayer.fromJson(json['isha'] as Map<String, dynamic>),
      jumuah: json['jumuah'] != null 
        ? Prayer.fromJson(json['jumuah'] as Map<String, dynamic>) 
        : null,
      mosqueId: json['mosqueId'] as String?,
      cachedAt: json['cachedAt'] != null 
        ? DateTime.parse(json['cachedAt'] as String) 
        : null,
    );
  }
}
