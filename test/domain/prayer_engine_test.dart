import 'package:flutter_test/flutter_test.dart';
import 'package:iqamah/domain/services/prayer_engine.dart';

void main() {
  group('PrayerEngine', () {
    late PrayerEngine engine;
    late PrayerTimes schedule;

    setUp(() {
      engine = const PrayerEngine();
      schedule = PrayerTimes(
        date: DateTime(2024, 1, 15),
        fajr: Prayer(
          name: 'Fajr',
          adhan: DateTime(2024, 1, 15, 5, 30),
          iqama: DateTime(2024, 1, 15, 5, 45),
        ),
        dhuhr: Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        ),
        asr: Prayer(
          name: 'Asr',
          adhan: DateTime(2024, 1, 15, 15, 45),
          iqama: DateTime(2024, 1, 15, 16, 0),
        ),
        maghrib: Prayer(
          name: 'Maghrib',
          adhan: DateTime(2024, 1, 15, 18, 15),
          iqama: DateTime(2024, 1, 15, 18, 25),
        ),
        isha: Prayer(
          name: 'Isha',
          adhan: DateTime(2024, 1, 15, 19, 45),
          iqama: DateTime(2024, 1, 15, 20, 0),
        ),
      );
    });

    group('getNextPrayer', () {
      test('returns first prayer when before Fajr', () {
        final now = DateTime(2024, 1, 15, 4, 0);
        final result = engine.getNextPrayer(schedule, now);

        expect(result.prayer.name, 'Fajr');
        expect(result.timeUntilAdhan, const Duration(hours: 1, minutes: 30));
        expect(result.timeUntilIqama, const Duration(hours: 1, minutes: 45));
        expect(result.isTomorrow, false);
      });

      test('returns next prayer when between prayers', () {
        final now = DateTime(2024, 1, 15, 14, 0);
        final result = engine.getNextPrayer(schedule, now);

        expect(result.prayer.name, 'Asr');
        expect(result.timeUntilAdhan, const Duration(hours: 1, minutes: 45));
      });

      test('returns tomorrow Fajr when after Isha', () {
        final now = DateTime(2024, 1, 15, 21, 0);
        final result = engine.getNextPrayer(schedule, now);

        expect(result.prayer.name, 'Fajr');
        expect(result.isTomorrow, true);
        expect(result.timeUntilAdhan, const Duration(hours: 8, minutes: 30));
      });

      test('handles being between adhan and iqama', () {
        final now = DateTime(2024, 1, 15, 12, 35);
        final result = engine.getNextPrayer(schedule, now);

        expect(result.prayer.name, 'Dhuhr');
        expect(result.timeUntilAdhan, Duration.zero);
        expect(result.timeUntilIqama, const Duration(minutes: 10));
      });
    });

    group('estimateRakah', () {
      test('returns not_started when before prayer start', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 12, 44); // 1 minute before start with 0 lag

        final result = engine.estimateRakah(prayer, now);

        expect(result.status, 'not_started');
        expect(result.totalRakah, 4);
        expect(result.currentRakah, null);
        expect(result.progress, 0);
      });

      test('calculates first rakah correctly', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 12, 46); // 1 minute after start

        final result = engine.estimateRakah(prayer, now);

        expect(result.status, 'in_progress');
        expect(result.currentRakah, 1);
        expect(result.totalRakah, 4);
        expect(result.progress, greaterThan(0));
      });

      test('calculates second rakah after duration', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 12, 48); // 3 minutes after start

        final result = engine.estimateRakah(prayer, now);

        expect(result.status, 'in_progress');
        expect(result.currentRakah, 2);
      });

      test('returns likely_finished after grace period', () {
        final prayer = Prayer(
          name: 'Fajr', // 2 rakahs
          adhan: DateTime(2024, 1, 15, 5, 30),
          iqama: DateTime(2024, 1, 15, 5, 45),
        );
        // Fajr: 2 rakahs * 144s = 288s = 4m 48s, plus 60s grace = ~6m after iqama
        final now = DateTime(2024, 1, 15, 5, 52); // 7 minutes after iqama

        final result = engine.estimateRakah(prayer, now);

        expect(result.status, 'likely_finished');
        expect(result.currentRakah, 2);
      });

      test('returns not_available when no iqama', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: null,
        );
        final now = DateTime(2024, 1, 15, 12, 50);

        final result = engine.estimateRakah(prayer, now);

        expect(result.status, 'not_available');
        expect(result.isEstimate, false);
      });

      test('clamps rakah index to total', () {
        final prayer = Prayer(
          name: 'Maghrib', // 3 rakahs
          adhan: DateTime(2024, 1, 15, 18, 15),
          iqama: DateTime(2024, 1, 15, 18, 25),
        );
        // 3 rakahs * 144s = 432s = 7m 12s, within grace period
        final now = DateTime(2024, 1, 15, 18, 35); // 10 minutes after iqama

        final result = engine.estimateRakah(prayer, now);

        expect(result.currentRakah, 3); // Should clamp to 3, not exceed
        expect(result.totalRakah, 3);
      });
    });

    group('calculateTravelPrediction', () {
      test('predicts before start arrival', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 11, 30); // 1 hour before
        final travelTime = const Duration(minutes: 10);

        final result = engine.calculateTravelPrediction(prayer, travelTime, now);

        expect(result.arrivalStatus, 'before_start');
        expect(result.arrivalRakah, 0);
        expect(result.shouldLeaveNow, false);
        expect(result.isLate, false);
      });

      test('predicts which rakah user will catch', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        // Prayer starts at 12:45
        // User arrives at 12:55 (10 min travel)
        // 10 min after start = 600s / 144s = 4.16 -> rakah 4
        final now = DateTime(2024, 1, 15, 12, 45); // Leave at iqama time
        final travelTime = const Duration(minutes: 10);

        final result = engine.calculateTravelPrediction(prayer, travelTime, now);

        expect(result.arrivalStatus, 'in_progress');
        expect(result.arrivalRakah, 4); // Catching last rakah
      });

      test('detects should leave now', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        // Should leave 30s before 12:45, so at 12:15 for 30 min travel
        final now = DateTime(2024, 1, 15, 12, 14);
        final travelTime = const Duration(minutes: 30);

        final result = engine.calculateTravelPrediction(prayer, travelTime, now);

        expect(result.shouldLeaveNow, true);
      });

      test('detects late departure', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 12, 50); // After prayer started
        final travelTime = const Duration(minutes: 5);

        final result = engine.calculateTravelPrediction(prayer, travelTime, now);

        expect(result.isLate, true);
        expect(result.shouldLeaveNow, true);
      });

      test('handles iqama unavailable', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: null,
        );
        final now = DateTime(2024, 1, 15, 12, 0);
        final travelTime = const Duration(minutes: 15);

        final result = engine.calculateTravelPrediction(prayer, travelTime, now);

        expect(result.arrivalStatus, 'iqama_unavailable');
        expect(result.arrivalRakah, null);
      });
    });

    group('getCountdown', () {
      test('returns time until iqama', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 12, 35);

        final result = engine.getCountdown(prayer, now);

        expect(result, const Duration(minutes: 10));
      });

      test('returns zero when after iqama', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        final now = DateTime(2024, 1, 15, 13, 0);

        final result = engine.getCountdown(prayer, now);

        expect(result, Duration.zero);
      });

      test('returns null when no iqama', () {
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: null,
        );
        final now = DateTime(2024, 1, 15, 12, 35);

        final result = engine.getCountdown(prayer, now);

        expect(result, null);
      });
    });

    group('formatDuration', () {
      test('formats hours and minutes', () {
        expect(
          engine.formatDuration(const Duration(hours: 2, minutes: 30)),
          '2h 30m',
        );
      });

      test('formats minutes and seconds', () {
        expect(
          engine.formatDuration(const Duration(minutes: 5, seconds: 30)),
          '5m 30s',
        );
      });

      test('formats only seconds', () {
        expect(
          engine.formatDuration(const Duration(seconds: 45)),
          '45s',
        );
      });
    });

    group('getCurrentPrayer', () {
      test('returns current prayer during Dhuhr', () {
        final now = DateTime(2024, 1, 15, 13, 0); // Between Dhuhr and Asr
        final result = engine.getCurrentPrayer(schedule, now);

        expect(result?.name, 'Dhuhr');
      });

      test('returns null before Fajr', () {
        final now = DateTime(2024, 1, 15, 4, 0);
        final result = engine.getCurrentPrayer(schedule, now);

        expect(result, null);
      });
    });

    group('custom config', () {
      test('uses custom rakah duration', () {
        const customConfig = PrayerEngineConfig(
          rakahDurationSeconds: 180, // 3 minutes
        );
        final customEngine = PrayerEngine(config: customConfig);
        
        final prayer = Prayer(
          name: 'Fajr',
          adhan: DateTime(2024, 1, 15, 5, 30),
          iqama: DateTime(2024, 1, 15, 5, 45),
        );
        // 5 minutes after start, with 180s per rakah = 300s / 180s = 1.67 -> rakah 2
        final now = DateTime(2024, 1, 15, 5, 50);

        final result = customEngine.estimateRakah(prayer, now);

        expect(result.currentRakah, 2);
      });

      test('uses custom start lag', () {
        const customConfig = PrayerEngineConfig(
          startLagSeconds: 300, // 5 minute delay
        );
        final customEngine = PrayerEngine(config: customConfig);
        
        final prayer = Prayer(
          name: 'Dhuhr',
          adhan: DateTime(2024, 1, 15, 12, 30),
          iqama: DateTime(2024, 1, 15, 12, 45),
        );
        // 12:47 - iqama was 12:45, 5 min lag means start is 12:50
        final now = DateTime(2024, 1, 15, 12, 47);

        final result = customEngine.estimateRakah(prayer, now);

        expect(result.status, 'not_started'); // Still not started with 5 min lag
      });
    });
  });
}
