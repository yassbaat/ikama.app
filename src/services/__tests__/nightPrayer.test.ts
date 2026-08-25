import { describe, it, expect } from 'vitest';
import {
  calculateNightPrayer,
  formatDuration,
  formatTime,
  isNightPeriod,
  isBetweenIshaAndFajr,
  type NightPrayerInfo,
} from '../nightPrayer';

describe('Night Prayer Service', () => {
  describe('calculateNightPrayer', () => {
    it('should calculate last third of the night correctly', () => {
      // Night from 6 PM to 5 AM (11 hours total)
      // Last third = 3 hours 40 min, starting at 1:20 AM
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-07T20:00:00'); // 8 PM (in first third)

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result).not.toBeNull();
      expect(result?.isActive).toBe(false);
      expect(result?.timeUntilStartSeconds).toBeGreaterThan(0);
      expect(result?.progress).toBe(0);
      expect(result?.durationSeconds).toBe(13200); // 3h 40m = 13200 seconds
    });

    it('should detect active last third period', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-08T02:00:00'); // 2 AM (in last third)

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result?.isActive).toBe(true);
      expect(result?.timeUntilStartSeconds).toBeNull();
      expect(result?.timeUntilFajrSeconds).toBeGreaterThan(0);
      expect(result?.progress).toBeGreaterThan(0);
      expect(result?.progress).toBeLessThan(1);
    });

    it('should return null for invalid times', () => {
      const result = calculateNightPrayer('invalid', '2026-02-08T05:00:00');
      expect(result).toBeNull();
    });

    it('should return null if maghrib is after fajr (same day)', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-07T05:00:00').toISOString(); // Same day, before maghrib

      const result = calculateNightPrayer(maghribTime, fajrTime);

      expect(result).toBeNull();
    });

    it('should handle progress correctly at start of last third', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T06:00:00').toISOString();
      // Last third starts at: 18:00 + (12h * 2/3) = 18:00 + 8h = 02:00
      const now = new Date('2026-02-08T02:00:00');

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result?.isActive).toBe(true);
      expect(result?.progress).toBe(0);
    });

    it('should handle progress correctly near end of last third', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T06:00:00').toISOString();
      // Last third ends at Fajr
      const now = new Date('2026-02-08T05:55:00');

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result?.isActive).toBe(true);
      expect(result?.progress).toBeGreaterThan(0.9);
      expect(result?.progress).toBeLessThanOrEqual(1);
    });

    it('should show correct display text when in last third', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T06:00:00').toISOString();
      const now = new Date('2026-02-08T03:00:00');

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result?.displayText).toBe('Last third of the night - Best time for night prayer');
    });

    it('should show correct display text before last third', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T06:00:00').toISOString();
      const now = new Date('2026-02-07T22:00:00');

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result?.displayText).toContain('Last third starts in');
      expect(result?.displayText).toContain('hour');
    });

    it('should show correct display text after Fajr', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T06:00:00').toISOString();
      const now = new Date('2026-02-08T07:00:00');

      const result = calculateNightPrayer(maghribTime, fajrTime, now);

      expect(result?.displayText).toBe('Night prayer time has passed');
      expect(result?.isActive).toBe(false);
      expect(result?.timeUntilFajrSeconds).toBeNull();
    });

    it('should calculate correct end time', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();

      const result = calculateNightPrayer(maghribTime, fajrTime);

      expect(result?.endTime).toBe(fajrTime);
    });
  });

  describe('formatDuration', () => {
    it('should format hours and minutes', () => {
      expect(formatDuration(3660)).toBe('1h 1m');
      expect(formatDuration(7200)).toBe('2h');
    });

    it('should format minutes only', () => {
      expect(formatDuration(1800)).toBe('30m');
      expect(formatDuration(60)).toBe('1m');
    });

    it('should handle zero', () => {
      expect(formatDuration(0)).toBe('0m');
    });

    it('should handle negative values', () => {
      expect(formatDuration(-60)).toBe('0m');
    });
  });

  describe('formatTime', () => {
    it('should format ISO string to readable time', () => {
      const isoString = new Date('2026-02-07T05:30:00').toISOString();
      const result = formatTime(isoString);
      
      // Should contain hour and minute
      expect(result).toMatch(/\d{1,2}:\d{2}/);
    });

    it('should handle different times of day', () => {
      const morning = new Date('2026-02-07T08:00:00').toISOString();
      const afternoon = new Date('2026-02-07T14:30:00').toISOString();
      const evening = new Date('2026-02-07T20:00:00').toISOString();

      expect(formatTime(morning)).toMatch(/\d{1,2}:\d{2}/);
      expect(formatTime(afternoon)).toMatch(/\d{1,2}:\d{2}/);
      expect(formatTime(evening)).toMatch(/\d{1,2}:\d{2}/);
    });
  });

  describe('isNightPeriod', () => {
    it('should return true during night period', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-07T22:00:00');

      expect(isNightPeriod(maghribTime, fajrTime, now)).toBe(true);
    });

    it('should return false before maghrib', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-07T17:00:00');

      expect(isNightPeriod(maghribTime, fajrTime, now)).toBe(false);
    });

    it('should return false after fajr', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-08T06:00:00');

      expect(isNightPeriod(maghribTime, fajrTime, now)).toBe(false);
    });

    it('should return true exactly at maghrib', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-07T18:00:00');

      expect(isNightPeriod(maghribTime, fajrTime, now)).toBe(true);
    });

    it('should return false exactly at fajr', () => {
      const maghribTime = new Date('2026-02-07T18:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-08T05:00:00');

      expect(isNightPeriod(maghribTime, fajrTime, now)).toBe(false);
    });
  });

  describe('isBetweenIshaAndFajr', () => {
    it('should return true between isha and fajr', () => {
      const ishaTime = new Date('2026-02-07T20:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-08T02:00:00');

      expect(isBetweenIshaAndFajr(ishaTime, fajrTime, now)).toBe(true);
    });

    it('should return false before isha', () => {
      const ishaTime = new Date('2026-02-07T20:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-07T19:00:00');

      expect(isBetweenIshaAndFajr(ishaTime, fajrTime, now)).toBe(false);
    });

    it('should return false after fajr', () => {
      const ishaTime = new Date('2026-02-07T20:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-08T06:00:00');

      expect(isBetweenIshaAndFajr(ishaTime, fajrTime, now)).toBe(false);
    });

    it('should return true exactly at isha', () => {
      const ishaTime = new Date('2026-02-07T20:00:00').toISOString();
      const fajrTime = new Date('2026-02-08T05:00:00').toISOString();
      const now = new Date('2026-02-07T20:00:00');

      expect(isBetweenIshaAndFajr(ishaTime, fajrTime, now)).toBe(true);
    });
  });

  describe('Integration scenarios', () => {
    it('should handle a typical Ramadan night schedule', () => {
      // Ramadan schedule with longer nights
      const maghribTime = new Date('2026-03-15T18:30:00').toISOString();
      const ishaTime = new Date('2026-03-15T20:15:00').toISOString();
      const fajrTime = new Date('2026-03-16T05:15:00').toISOString();

      // After Maghrib, before last third
      const afterMaghrib = new Date('2026-03-15T21:00:00');
      let result = calculateNightPrayer(maghribTime, fajrTime, afterMaghrib);
      expect(result?.isActive).toBe(false);

      // In last third (after ~00:20)
      const inLastThird = new Date('2026-03-16T02:00:00');
      result = calculateNightPrayer(maghribTime, fajrTime, inLastThird);
      expect(result?.isActive).toBe(true);

      // Verify night period
      expect(isNightPeriod(maghribTime, fajrTime, afterMaghrib)).toBe(true);
      expect(isBetweenIshaAndFajr(ishaTime, fajrTime, inLastThird)).toBe(true);
    });

    it('should handle short winter nights', () => {
      // Winter schedule with shorter nights
      const maghribTime = new Date('2026-12-15T17:00:00').toISOString();
      const fajrTime = new Date('2026-12-16T06:30:00').toISOString();

      // Total night: 13.5 hours, last third: 4.5 hours, starts at ~02:00
      const inLastThird = new Date('2026-12-16T03:00:00');
      const result = calculateNightPrayer(maghribTime, fajrTime, inLastThird);

      expect(result?.isActive).toBe(true);
      expect(result?.durationSeconds).toBe(16200); // 4.5 hours
    });

    it('should handle summer nights', () => {
      // Summer schedule with short nights
      const maghribTime = new Date('2026-06-15T21:00:00').toISOString();
      const fajrTime = new Date('2026-06-16T03:30:00').toISOString();

      // Total night: 6.5 hours, last third: ~2.17 hours, starts at ~01:41
      const inLastThird = new Date('2026-06-16T02:00:00');
      const result = calculateNightPrayer(maghribTime, fajrTime, inLastThird);

      expect(result?.isActive).toBe(true);
    });
  });
});
