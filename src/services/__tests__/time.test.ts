import {
  formatCountdown,
  formatTime,
  formatTimeUntil,
  formatDuration,
  getTimeRemaining,
  hasPrayerPassed,
  getUrgencyColor,
  isPrayerActive,
  isPrayerInProgress,
  formatLiveTimer,
} from '../time';

describe('Time Service', () => {
  describe('formatCountdown', () => {
    it('should format with hours, minutes, seconds', () => {
      expect(formatCountdown(3665)).toBe('1h 01m 05s');
    });

    it('should format with minutes and seconds only', () => {
      expect(formatCountdown(125)).toBe('2m 05s');
    });

    it('should format seconds only', () => {
      expect(formatCountdown(45)).toBe('45s');
    });

    it('should handle zero', () => {
      expect(formatCountdown(0)).toBe('0s');
    });
  });

  describe('formatTime', () => {
    it('should format time correctly', () => {
      const dateStr = new Date('2026-02-05T05:30:00').toISOString();
      expect(formatTime(dateStr)).toMatch(/5:30\s*(AM|PM)/);
    });
  });

  describe('formatTimeUntil', () => {
    it('should return "Now" for zero or negative', () => {
      expect(formatTimeUntil(0)).toBe('Now');
      expect(formatTimeUntil(-10)).toBe('Now');
    });

    it('should format hours and minutes', () => {
      expect(formatTimeUntil(3660)).toBe('1h 1m');
    });

    it('should format minutes only', () => {
      expect(formatTimeUntil(300)).toBe('5m');
    });
  });

  describe('formatDuration', () => {
    it('should return "Now" for zero', () => {
      expect(formatDuration(0)).toBe('Now');
    });

    it('should format hours', () => {
      expect(formatDuration(7200)).toBe('2h 0m');
    });

    it('should format minutes and seconds', () => {
      expect(formatDuration(125)).toBe('2m 5s');
    });
  });

  describe('getTimeRemaining', () => {
    it('should calculate time remaining correctly', () => {
      const future = new Date(Date.now() + 60000).toISOString();
      const remaining = getTimeRemaining(future);
      
      expect(remaining).toBeGreaterThan(55);
      expect(remaining).toBeLessThanOrEqual(60);
    });

    it('should return negative for past time', () => {
      const past = new Date(Date.now() - 60000).toISOString();
      expect(getTimeRemaining(past)).toBeLessThan(0);
    });
  });

  describe('hasPrayerPassed', () => {
    it('should return true for past prayer', () => {
      const past = new Date(Date.now() - 60000).toISOString();
      expect(hasPrayerPassed(past)).toBe(true);
    });

    it('should return false for future prayer', () => {
      const future = new Date(Date.now() + 60000).toISOString();
      expect(hasPrayerPassed(future)).toBe(false);
    });
  });

  describe('getUrgencyColor', () => {
    it('should return expired color', () => {
      expect(getUrgencyColor(0)).toBe('text-gray-500');
      expect(getUrgencyColor(-1)).toBe('text-gray-500');
    });

    it('should return urgent color', () => {
      expect(getUrgencyColor(299)).toBe('text-red-400');
    });

    it('should return soon color', () => {
      expect(getUrgencyColor(600)).toBe('text-orange-400');
    });

    it('should return warning color', () => {
      expect(getUrgencyColor(1200)).toBe('text-yellow-400');
    });

    it('should return normal color', () => {
      expect(getUrgencyColor(3600)).toBe('text-emerald-400');
    });
  });

  describe('isPrayerActive', () => {
    const now = new Date();
    const adhan = new Date(now.getTime() - 300000).toISOString(); // 5 min ago
    const iqama = new Date(now.getTime() + 600000).toISOString();  // 10 min from now

    it('should return true when between adhan and iqama', () => {
      expect(isPrayerActive(adhan, iqama)).toBe(true);
    });

    it('should return false when before adhan', () => {
      const futureAdhan = new Date(now.getTime() + 300000).toISOString();
      expect(isPrayerActive(futureAdhan, iqama)).toBe(false);
    });

    it('should return false when after iqama', () => {
      const pastIqama = new Date(now.getTime() - 300000).toISOString();
      expect(isPrayerActive(adhan, pastIqama)).toBe(false);
    });

    it('should return false when no iqama', () => {
      expect(isPrayerActive(adhan, null)).toBe(false);
    });
  });

  describe('isPrayerInProgress', () => {
    const now = new Date();

    it('should return true when within prayer duration', () => {
      const iqama = new Date(now.getTime() - 300000).toISOString(); // 5 min ago
      expect(isPrayerInProgress(iqama, 15)).toBe(true);
    });

    it('should return false when prayer finished', () => {
      const iqama = new Date(now.getTime() - 1200000).toISOString(); // 20 min ago
      expect(isPrayerInProgress(iqama, 15)).toBe(false);
    });

    it('should return false when no iqama', () => {
      expect(isPrayerInProgress(null, 15)).toBe(false);
    });
  });

  describe('formatLiveTimer', () => {
    it('should format with hours', () => {
      const result = formatLiveTimer(3665);
      expect(result.hours).toBe('01');
      expect(result.minutes).toBe('01');
      expect(result.seconds).toBe('05');
      expect(result.display).toBe('01:01:05');
    });

    it('should format without hours', () => {
      const result = formatLiveTimer(125);
      expect(result.hours).toBe('00');
      expect(result.minutes).toBe('02');
      expect(result.seconds).toBe('05');
      expect(result.display).toBe('02:05');
    });

    it('should handle zero', () => {
      const result = formatLiveTimer(0);
      expect(result.display).toBe('00:00');
    });
  });
});
