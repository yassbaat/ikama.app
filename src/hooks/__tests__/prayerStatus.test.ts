import { renderHook, act, waitFor } from '@testing-library/react';
import { usePrayerTimes, useRakahEstimate } from '../usePrayerTimes';
import { useStore } from '../useStore';
import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest';

// Mock the store
vi.mock('../useStore');

describe('Prayer Status Integration Tests', () => {
  const mockSetNextPrayer = vi.fn();
  const mockSetCountdowns = vi.fn();
  const mockSetRakahEstimate = vi.fn();
  const mockSetError = vi.fn();

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    
    (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
      setNextPrayer: mockSetNextPrayer,
      setCountdowns: mockSetCountdowns,
      setRakahEstimate: mockSetRakahEstimate,
      setError: mockSetError,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  describe('Prayer Countdown Updates', () => {
    it('should update countdown every second', async () => {
      const mockPrayerTimes = {
        fajr: {
          name: 'Fajr',
          adhan: new Date(Date.now() + 3600000).toISOString(), // 1 hour from now
          iqama: new Date(Date.now() + 3750000).toISOString(), // 1h 2.5m from now
        },
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(Date.now() + 7200000).toISOString(),
          iqama: new Date(Date.now() + 7350000).toISOString(),
        },
        asr: {
          name: 'Asr',
          adhan: new Date(Date.now() + 10800000).toISOString(),
          iqama: new Date(Date.now() + 10950000).toISOString(),
        },
        maghrib: {
          name: 'Maghrib',
          adhan: new Date(Date.now() + 14400000).toISOString(),
          iqama: new Date(Date.now() + 14430000).toISOString(),
        },
        isha: {
          name: 'Isha',
          adhan: new Date(Date.now() + 18000000).toISOString(),
          iqama: new Date(Date.now() + 18150000).toISOString(),
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setNextPrayer: mockSetNextPrayer,
        setCountdowns: mockSetCountdowns,
        setError: mockSetError,
      });

      renderHook(() => usePrayerTimes());

      // Initial call
      expect(mockSetNextPrayer).toHaveBeenCalled();
      expect(mockSetCountdowns).toHaveBeenCalled();

      // Advance 1 second
      act(() => {
        vi.advanceTimersByTime(1000);
      });

      await waitFor(() => {
        expect(mockSetCountdowns).toHaveBeenCalledTimes(2);
      });
    });

    it('should detect active prayer (between adhan and iqama)', async () => {
      const now = Date.now();
      const mockPrayerTimes = {
        fajr: {
          name: 'Fajr',
          adhan: new Date(now - 300000).toISOString(), // 5 min ago (passed)
          iqama: new Date(now - 120000).toISOString(), // 2 min ago (passed)
        },
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 300000).toISOString(), // 5 min ago (active)
          iqama: new Date(now + 600000).toISOString(), // 10 min from now
        },
        asr: {
          name: 'Asr',
          adhan: new Date(now + 3600000).toISOString(), // 1 hour from now
          iqama: new Date(now + 3750000).toISOString(),
        },
        maghrib: {
          name: 'Maghrib',
          adhan: new Date(now + 7200000).toISOString(),
          iqama: new Date(now + 7230000).toISOString(),
        },
        isha: {
          name: 'Isha',
          adhan: new Date(now + 10800000).toISOString(),
          iqama: new Date(now + 10950000).toISOString(),
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setNextPrayer: mockSetNextPrayer,
        setCountdowns: mockSetCountdowns,
        setError: mockSetError,
      });

      renderHook(() => usePrayerTimes());

      await waitFor(() => {
        const countdownsCall = mockSetCountdowns.mock.calls[0][0];
        const dhuhrCountdown = countdownsCall.find((c: any) => c.prayer_name === 'Dhuhr');
        
        expect(dhuhrCountdown.is_active).toBe(true);
        expect(dhuhrCountdown.time_until_adhan_secs).toBe(0);
      });
    });

    it('should handle midnight crossover', async () => {
      const now = Date.now();
      const mockPrayerTimes = {
        fajr: {
          name: 'Fajr',
          adhan: new Date(now + 3600000).toISOString(), // 1 hour from now (tomorrow's Fajr)
          iqama: new Date(now + 3750000).toISOString(),
        },
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 18000000).toISOString(), // 5 hours ago (passed)
          iqama: new Date(now - 17850000).toISOString(),
        },
        asr: {
          name: 'Asr',
          adhan: new Date(now - 14400000).toISOString(),
          iqama: new Date(now - 14250000).toISOString(),
        },
        maghrib: {
          name: 'Maghrib',
          adhan: new Date(now - 10800000).toISOString(),
          iqama: new Date(now - 10770000).toISOString(),
        },
        isha: {
          name: 'Isha',
          adhan: new Date(now - 7200000).toISOString(), // 2 hours ago (passed)
          iqama: new Date(now - 7050000).toISOString(),
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setNextPrayer: mockSetNextPrayer,
        setCountdowns: mockSetCountdowns,
        setError: mockSetError,
      });

      renderHook(() => usePrayerTimes());

      await waitFor(() => {
        const nextPrayerCall = mockSetNextPrayer.mock.calls[0][0];
        
        expect(nextPrayerCall.prayer.name).toBe('Fajr');
        expect(nextPrayerCall.is_tomorrow).toBe(true);
      });
    });
  });

  describe('Rakah Estimation', () => {
    it('should estimate not_started before iqama', () => {
      const now = Date.now();
      const mockPrayerTimes = {
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 600000).toISOString(),
          iqama: new Date(now + 600000).toISOString(), // 10 min from now
          custom_rakah_count: 4,
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Dhuhr'));

      expect(mockSetRakahEstimate).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'not_started',
          total_rakah: 4,
          progress: 0,
        })
      );
    });

    it('should estimate in_progress during prayer', () => {
      const now = Date.now();
      const mockPrayerTimes = {
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 900000).toISOString(),
          iqama: new Date(now - 300000).toISOString(), // 5 min ago
          custom_rakah_count: 4,
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Dhuhr'));

      expect(mockSetRakahEstimate).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'in_progress',
          total_rakah: 4,
        })
      );

      const estimate = mockSetRakahEstimate.mock.calls[0][0];
      expect(estimate.current_rakah).toBeGreaterThanOrEqual(1);
      expect(estimate.current_rakah).toBeLessThanOrEqual(4);
      expect(estimate.progress).toBeGreaterThan(0);
    });

    it('should estimate likely_finished after prayer', () => {
      const now = Date.now();
      const mockPrayerTimes = {
        fajr: {
          name: 'Fajr',
          adhan: new Date(now - 1800000).toISOString(),
          iqama: new Date(now - 1500000).toISOString(), // 25 min ago (should be finished)
          custom_rakah_count: 2,
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Fajr'));

      expect(mockSetRakahEstimate).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'likely_finished',
          total_rakah: 2,
          progress: 1.0,
        })
      );
    });

    it('should calculate correct rakah for different prayers', () => {
      const testCases = [
        { name: 'Fajr', rakahCount: 2 },
        { name: 'Dhuhr', rakahCount: 4 },
        { name: 'Asr', rakahCount: 4 },
        { name: 'Maghrib', rakahCount: 3 },
        { name: 'Isha', rakahCount: 4 },
      ];

      const now = Date.now();

      testCases.forEach(({ name, rakahCount }) => {
        vi.clearAllMocks();
        
        const mockPrayerTimes = {
          [name.toLowerCase()]: {
            name,
            adhan: new Date(now - 600000).toISOString(),
            iqama: new Date(now - 120000).toISOString(), // 2 min ago
            custom_rakah_count: rakahCount,
          },
        };

        (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
          currentMosque: { id: 'test', name: 'Test Mosque' },
          currentPrayerTimes: mockPrayerTimes,
          setRakahEstimate: mockSetRakahEstimate,
        });

        renderHook(() => useRakahEstimate(name));

        expect(mockSetRakahEstimate).toHaveBeenCalledWith(
          expect.objectContaining({
            total_rakah: rakahCount,
          })
        );
      });
    });

    it('should update rakah estimate every 10 seconds', async () => {
      const now = Date.now();
      const mockPrayerTimes = {
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 600000).toISOString(),
          iqama: new Date(now - 120000).toISOString(), // 2 min ago
          custom_rakah_count: 4,
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Dhuhr'));

      const initialCallCount = mockSetRakahEstimate.mock.calls.length;

      act(() => {
        vi.advanceTimersByTime(10000);
      });

      await waitFor(() => {
        expect(mockSetRakahEstimate.mock.calls.length).toBeGreaterThan(initialCallCount);
      });
    });

    it('should handle prayers without iqama', () => {
      const now = Date.now();
      const mockPrayerTimes = {
        test: {
          name: 'Test',
          adhan: new Date(now - 600000).toISOString(),
          iqama: null,
          custom_rakah_count: 4,
        },
      };

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Test'));

      expect(mockSetRakahEstimate).toHaveBeenCalledWith({
        status: 'not_available',
        total_rakah: 4,
        progress: 0,
        is_estimate: false,
      });
    });
  });
});
