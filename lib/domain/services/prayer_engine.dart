import 'package:flutter/foundation.dart';

/// Configuration for the PrayerEngine
class PrayerEngineConfig {
  final int rakahDurationSeconds;
  final int startLagSeconds;
  final int bufferBeforeStartSeconds;
  final int graceSeconds;
  final Map<String, int> defaultRakahCounts;

  const PrayerEngineConfig({
    this.rakahDurationSeconds = 144, // 2.4 minutes
    this.startLagSeconds = 0,
    this.bufferBeforeStartSeconds = 30,
    this.graceSeconds = 60,
    this.defaultRakahCounts = const {
      'Fajr': 2,
      'Dhuhr': 4,
      'Asr': 4,
      'Maghrib': 3,
      'Isha': 4,
      'Jumuah': 2,
    },
  });

  PrayerEngineConfig copyWith({
    int? rakahDurationSeconds,
    int? startLagSeconds,
    int? bufferBeforeStartSeconds,
    int? graceSeconds,
    Map<String, int>? defaultRakahCounts,
  }) {
    return PrayerEngineConfig(
      rakahDurationSeconds: rakahDurationSeconds ?? this.rakahDurationSeconds,
      startLagSeconds: startLagSeconds ?? this.startLagSeconds,
      bufferBeforeStartSeconds: bufferBeforeStartSeconds ?? this.bufferBeforeStartSeconds,
      graceSeconds: graceSeconds ?? this.graceSeconds,
      defaultRakahCounts: defaultRakahCounts ?? this.defaultRakahCounts,
    );
  }
}

/// Prayer data class
class Prayer {
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
}

/// Prayer times for a day
class PrayerTimes {
  final DateTime date;
  final Prayer fajr;
  final Prayer dhuhr;
  final Prayer asr;
  final Prayer maghrib;
  final Prayer isha;
  final Prayer? jumuah;

  const PrayerTimes({
    required this.date,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.jumuah,
  });

  List<Prayer> get allPrayers => [
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
  ];

  Prayer? getPrayerByName(String name) {
    switch (name) {
      case 'Fajr':
        return fajr;
      case 'Dhuhr':
        return dhuhr;
      case 'Asr':
        return asr;
      case 'Maghrib':
        return maghrib;
      case 'Isha':
        return isha;
      case 'Jumuah':
        return jumuah;
      default:
        return null;
    }
  }
}

/// Result for next prayer calculation
class NextPrayerResult {
  final Prayer prayer;
  final Duration timeUntilAdhan;
  final Duration? timeUntilIqama;
  final bool isTomorrow;

  const NextPrayerResult({
    required this.prayer,
    required this.timeUntilAdhan,
    this.timeUntilIqama,
    this.isTomorrow = false,
  });

  bool get hasIqama => timeUntilIqama != null;
}

/// Rakah estimation result
class RakahEstimate {
  final String status; // 'not_started', 'in_progress', 'likely_finished'
  final int? currentRakah;
  final int totalRakah;
  final Duration? elapsed;
  final Duration? remaining;
  final double progress;
  final bool isEstimate;

  const RakahEstimate({
    required this.status,
    this.currentRakah,
    required this.totalRakah,
    this.elapsed,
    this.remaining,
    required this.progress,
    this.isEstimate = true,
  });

  static RakahEstimate notAvailable(int totalRakah) {
    return RakahEstimate(
      status: 'not_available',
      totalRakah: totalRakah,
      progress: 0,
      isEstimate: false,
    );
  }
}

/// Travel prediction result
class TravelPrediction {
  final DateTime recommendedLeaveTime;
  final DateTime arrivalTime;
  final int? arrivalRakah;
  final String arrivalStatus;
  final bool shouldLeaveNow;
  final Duration? timeUntilLeave;
  final bool isLate;

  const TravelPrediction({
    required this.recommendedLeaveTime,
    required this.arrivalTime,
    this.arrivalRakah,
    required this.arrivalStatus,
    required this.shouldLeaveNow,
    this.timeUntilLeave,
    required this.isLate,
  });
}

/// Core prayer calculation engine - Pure, stateless, testable
class PrayerEngine {
  final PrayerEngineConfig config;

  const PrayerEngine({this.config = const PrayerEngineConfig()});

  /// Get the next prayer from the schedule
  NextPrayerResult getNextPrayer(PrayerTimes schedule, DateTime now) {
    final prayers = schedule.allPrayers;
    
    // Find the next prayer
    for (final prayer in prayers) {
      if (prayer.adhan.isAfter(now)) {
        return NextPrayerResult(
          prayer: prayer,
          timeUntilAdhan: prayer.adhan.difference(now),
          timeUntilIqama: prayer.iqama?.difference(now),
          isTomorrow: false,
        );
      }
      // If we're between adhan and iqama
      if (prayer.iqama != null && 
          now.isAfter(prayer.adhan) && 
          now.isBefore(prayer.iqama!)) {
        return NextPrayerResult(
          prayer: prayer,
          timeUntilAdhan: Duration.zero,
          timeUntilIqama: prayer.iqama!.difference(now),
          isTomorrow: false,
        );
      }
    }

    // All prayers done for today, return tomorrow's Fajr
    final tomorrowFajr = DateTime(
      now.year, now.month, now.day + 1,
      schedule.fajr.adhan.hour,
      schedule.fajr.adhan.minute,
    );
    
    final tomorrowFajrIqama = schedule.fajr.iqama != null
      ? DateTime(
          now.year, now.month, now.day + 1,
          schedule.fajr.iqama!.hour,
          schedule.fajr.iqama!.minute,
        )
      : null;

    return NextPrayerResult(
      prayer: Prayer(
        name: schedule.fajr.name,
        adhan: tomorrowFajr,
        iqama: tomorrowFajrIqama,
      ),
      timeUntilAdhan: tomorrowFajr.difference(now),
      timeUntilIqama: tomorrowFajrIqama?.difference(now),
      isTomorrow: true,
    );
  }

  /// Estimate current rakah during prayer
  RakahEstimate estimateRakah(Prayer prayer, DateTime now) {
    if (!prayer.hasIqama) {
      return RakahEstimate.notAvailable(
        prayer.getRakahCount(config.defaultRakahCounts),
      );
    }

    final iqama = prayer.iqama!;
    final prayerStart = iqama.add(Duration(seconds: config.startLagSeconds));
    final totalRakah = prayer.getRakahCount(config.defaultRakahCounts);
    final estimatedDuration = Duration(
      seconds: totalRakah * config.rakahDurationSeconds,
    );
    final prayerEnd = prayerStart.add(estimatedDuration);
    final graceEnd = prayerEnd.add(Duration(seconds: config.graceSeconds));

    // Not started yet
    if (now.isBefore(prayerStart)) {
      return RakahEstimate(
        status: 'not_started',
        totalRakah: totalRakah,
        remaining: prayerStart.difference(now),
        progress: 0,
      );
    }

    // Likely finished
    if (now.isAfter(graceEnd)) {
      return RakahEstimate(
        status: 'likely_finished',
        currentRakah: totalRakah,
        totalRakah: totalRakah,
        elapsed: now.difference(prayerStart),
        progress: 1.0,
      );
    }

    // In progress - calculate rakah
    final elapsed = now.difference(prayerStart);
    final rawRakahIndex = elapsed.inSeconds ~/ config.rakahDurationSeconds + 1;
    final currentRakah = rawRakahIndex.clamp(1, totalRakah);
    final progress = elapsed.inSeconds / estimatedDuration.inSeconds;

    return RakahEstimate(
      status: 'in_progress',
      currentRakah: currentRakah,
      totalRakah: totalRakah,
      elapsed: elapsed,
      remaining: prayerEnd.isAfter(now) ? prayerEnd.difference(now) : Duration.zero,
      progress: progress.clamp(0.0, 1.0),
    );
  }

  /// Calculate travel prediction
  TravelPrediction calculateTravelPrediction(
    Prayer prayer,
    Duration travelTime,
    DateTime now,
  ) {
    if (!prayer.hasIqama) {
      return TravelPrediction(
        recommendedLeaveTime: now,
        arrivalTime: now.add(travelTime),
        arrivalStatus: 'iqama_unavailable',
        shouldLeaveNow: false,
        isLate: false,
      );
    }

    final iqama = prayer.iqama!;
    final prayerStart = iqama.add(Duration(seconds: config.startLagSeconds));
    final desiredArrival = prayerStart.subtract(
      Duration(seconds: config.bufferBeforeStartSeconds),
    );
    final recommendedLeave = desiredArrival.subtract(travelTime);
    final arrivalTime = now.add(travelTime);
    
    final totalRakah = prayer.getRakahCount(config.defaultRakahCounts);

    // Should leave now?
    final shouldLeaveNow = now.isAfter(recommendedLeave) || now.isAtSameMomentAs(recommendedLeave);
    final isLate = now.isAfter(prayerStart);

    // Calculate arrival rakah
    int? arrivalRakah;
    String arrivalStatus;

    if (arrivalTime.isBefore(prayerStart)) {
      arrivalRakah = 0;
      arrivalStatus = 'before_start';
    } else {
      final arrivalElapsed = arrivalTime.difference(prayerStart);
      final rawRakah = arrivalElapsed.inSeconds ~/ config.rakahDurationSeconds + 1;
      arrivalRakah = rawRakah.clamp(1, totalRakah);
      
      if (arrivalRakah > totalRakah) {
        arrivalStatus = 'after_estimated_end';
        arrivalRakah = null;
      } else {
        arrivalStatus = 'in_progress';
      }
    }

    return TravelPrediction(
      recommendedLeaveTime: recommendedLeave,
      arrivalTime: arrivalTime,
      arrivalRakah: arrivalRakah,
      arrivalStatus: arrivalStatus,
      shouldLeaveNow: shouldLeaveNow,
      timeUntilLeave: now.isBefore(recommendedLeave) 
        ? recommendedLeave.difference(now) 
        : null,
      isLate: isLate,
    );
  }

  /// Get countdown until iqama
  Duration? getCountdown(Prayer prayer, DateTime now) {
    if (prayer.iqama == null) return null;
    if (now.isAfter(prayer.iqama!)) return Duration.zero;
    return prayer.iqama!.difference(now);
  }

  /// Format duration for display
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get current or next prayer for a given time
  Prayer? getCurrentPrayer(PrayerTimes schedule, DateTime now) {
    final prayers = schedule.allPrayers;
    
    for (int i = 0; i < prayers.length; i++) {
      final prayer = prayers[i];
      final nextPrayer = i < prayers.length - 1 ? prayers[i + 1] : null;
      
      // Check if we're in this prayer's time window
      if (now.isAfter(prayer.adhan) && 
          (nextPrayer == null || now.isBefore(nextPrayer.adhan))) {
        return prayer;
      }
    }
    
    return null;
  }
}
