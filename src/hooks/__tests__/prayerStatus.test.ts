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

  // Helper to create complete mock prayer times
  const createMockPrayerTimes = (overrides: any = {}) => {
    const now = Date.now();
    return {
      fajr: {
        name: 'Fajr',
        adhan: new Date(now + 3600000).toISOString(),
        iqama: new Date(now + 3750000).toISOString(),
        ...overrides.fajr,
      },
      dhuhr: {
        name: 'Dhuhr',
        adhan: new Date(now + 7200000).toISOString(),
        iqama: new Date(now + 7350000).toISOString(),
        ...overrides.dhuhr,
      },
      asr: {
        name: 'Asr',
        adhan: new Date(now + 10800000).toISOString(),
        iqama: new Date(now + 10950000).toISOString(),
        ...overrides.asr,
      },
      maghrib: {
        name: 'Maghrib',
        adhan: new Date(now + 14400000).toISOString(),
        iqama: new Date(now + 14430000).toISOString(),
        ...overrides.maghrib,
      },
      isha: {
        name: 'Isha',
        adhan: new Date(now + 18000000).toISOString(),
        iqama: new Date(now + 18150000).toISOString(),
        ...overrides.isha,
      },
      ...overrides.other,
    };
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers({ shouldAdvanceTime: true });
    
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
      const mockPrayerTimes = createMockPrayerTimes();

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setNextPrayer: mockSetNextPrayer,
        setCountdowns: mockSetCountdowns,
        setError: mockSetError,
      });

      renderHook(() => usePrayerTimes());

      // Initial call
      await waitFor(() => {
        expect(mockSetNextPrayer).toHaveBeenCalled();
        expect(mockSetCountdowns).toHaveBeenCalled();
      });

      const initialCallCount = mockSetCountdowns.mock.calls.length;

      // Advance 1 second
      act(() => {
        vi.advanceTimersByTime(1000);
      });

      await waitFor(() => {
        expect(mockSetCountdowns.mock.calls.length).toBeGreaterThan(initialCallCount);
      });
    }, 10000);

    it('should detect active prayer (between adhan and iqama)', async () => {
      const now = Date.now();
      const mockPrayerTimes = createMockPrayerTimes({
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
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setNextPrayer: mockSetNextPrayer,
        setCountdowns: mockSetCountdowns,
        setError: mockSetError,
      });

      renderHook(() => usePrayerTimes());

      await waitFor(() => {
        const countdownsCall = mockSetCountdowns.mock.calls[0]?.[0];
        expect(countdownsCall).toBeDefined();
        
        const dhuhrCountdown = countdownsCall?.find((c: any) => c.prayer_name === 'Dhuhr');
        expect(dhuhrCountdown).toBeDefined();
        expect(dhuhrCountdown.is_active).toBe(true);
        expect(dhuhrCountdown.time_until_adhan_secs).toBe(0);
      });
    }, 10000);

    it('should handle midnight crossover', async () => {
      const now = Date.now();
      const mockPrayerTimes = createMockPrayerTimes({
        fajr: {
          name: 'Fajr',
          adhan: new Date(now + 50400000).toISOString(), // 14 hours from now (tomorrow's Fajr)
          iqama: new Date(now + 51900000).toISOString(),
        },
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 64800000).toISOString(), // 18 hours ago (passed yesterday)
          iqama: new Date(now - 64650000).toISOString(),
        },
        asr: {
          name: 'Asr',
          adhan: new Date(now - 57600000).toISOString(), // 16 hours ago
          iqama: new Date(now - 57450000).toISOString(),
        },
        maghrib: {
          name: 'Maghrib',
          adhan: new Date(now - 50400000).toISOString(), // 14 hours ago
          iqama: new Date(now - 50100000).toISOString(),
        },
        isha: {
          name: 'Isha',
          adhan: new Date(now - 36000000).toISOString(), // 10 hours ago (passed)
          iqama: new Date(now - 34500000).toISOString(),
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setNextPrayer: mockSetNextPrayer,
        setCountdowns: mockSetCountdowns,
        setError: mockSetError,
      });

      renderHook(() => usePrayerTimes());

      await waitFor(() => {
        const nextPrayerCall = mockSetNextPrayer.mock.calls[0]?.[0];
        expect(nextPrayerCall).toBeDefined();
        expect(nextPrayerCall.prayer.name).toBe('Fajr');
        expect(nextPrayerCall.is_tomorrow).toBe(true);
      });
    }, 10000);
  });

  describe('Rakah Estimation', () => {
    it('should estimate not_started before iqama', async () => {
      const now = Date.now();
      const mockPrayerTimes = createMockPrayerTimes({
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 600000).toISOString(),
          iqama: new Date(now + 600000).toISOString(), // 10 min from now
          custom_rakah_count: 4,
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Dhuhr'));

      await waitFor(() => {
        expect(mockSetRakahEstimate).toHaveBeenCalledWith(
          expect.objectContaining({
            status: 'not_started',
            total_rakah: 4,
            progress: 0,
          })
        );
      });
    }, 10000);

    it('should estimate in_progress during prayer', async () => {
      const now = Date.now();
      const mockPrayerTimes = createMockPrayerTimes({
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 900000).toISOString(),
          iqama: new Date(now - 300000).toISOString(), // 5 min ago
          custom_rakah_count: 4,
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Dhuhr'));

      await waitFor(() => {
        expect(mockSetRakahEstimate).toHaveBeenCalledWith(
          expect.objectContaining({
            status: 'in_progress',
            total_rakah: 4,
          })
        );

        const estimate = mockSetRakahEstimate.mock.calls[0]?.[0];
        expect(estimate.current_rakah).toBeGreaterThanOrEqual(1);
        expect(estimate.current_rakah).toBeLessThanOrEqual(4);
        expect(estimate.progress).toBeGreaterThan(0);
      });
    }, 10000);

    it('should estimate recently_finished after prayer', async () => {
      const now = Date.now();
      // Fajr = 2 rakahs = ~4.8 min. At 6 min after iqama, it should be "recently_finished"
      const mockPrayerTimes = createMockPrayerTimes({
        fajr: {
          name: 'Fajr',
          adhan: new Date(now - 1800000).toISOString(),
          iqama: new Date(now - 360000).toISOString(), // 6 min ago (within 28 min window)
          custom_rakah_count: 2,
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Fajr'));

      await waitFor(() => {
        const estimate = mockSetRakahEstimate.mock.calls[0]?.[0];
        expect(estimate.status).toBe('recently_finished');
        expect(estimate.total_rakah).toBe(2);
        expect(estimate.progress).toBe(1.0);
      });
    }, 10000);

    it('should estimate likely_finished long after prayer', async () => {
      const now = Date.now();
      // Fajr = 2 rakahs = ~4.8 min. At 35 min after iqama (past 28 min window)
      const mockPrayerTimes = createMockPrayerTimes({
        fajr: {
          name: 'Fajr',
          adhan: new Date(now - 3600000).toISOString(),
          iqama: new Date(now - 2100000).toISOString(), // 35 min ago (past 28 min window)
          custom_rakah_count: 2,
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Fajr'));

      await waitFor(() => {
        const estimate = mockSetRakahEstimate.mock.calls[0]?.[0];
        expect(estimate.status).toBe('likely_finished');
        expect(estimate.total_rakah).toBe(2);
        expect(estimate.progress).toBe(1.0);
        expect(estimate.can_still_catch).toBe(false);
      });
    }, 10000);

    it('should calculate correct rakah for different prayers', async () => {
      const testCases = [
        { name: 'Fajr', rakahCount: 2 },
        { name: 'Dhuhr', rakahCount: 4 },
        { name: 'Asr', rakahCount: 4 },
        { name: 'Maghrib', rakahCount: 3 },
        { name: 'Isha', rakahCount: 4 },
      ];

      const now = Date.now();

      for (const { name, rakahCount } of testCases) {
        vi.clearAllMocks();
        
        const mockPrayerTimes = createMockPrayerTimes({
          [name.toLowerCase()]: {
            name,
            adhan: new Date(now - 600000).toISOString(),
            iqama: new Date(now - 120000).toISOString(), // 2 min ago
            custom_rakah_count: rakahCount,
          },
        });

        (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
          currentMosque: { id: 'test', name: 'Test Mosque' },
          currentPrayerTimes: mockPrayerTimes,
          setRakahEstimate: mockSetRakahEstimate,
        });

        renderHook(() => useRakahEstimate(name));

        await waitFor(() => {
          expect(mockSetRakahEstimate).toHaveBeenCalledWith(
            expect.objectContaining({
              total_rakah: rakahCount,
            })
          );
        });
      }
    }, 30000);

    it('should update rakah estimate every 10 seconds', async () => {
      const now = Date.now();
      const mockPrayerTimes = createMockPrayerTimes({
        dhuhr: {
          name: 'Dhuhr',
          adhan: new Date(now - 600000).toISOString(),
          iqama: new Date(now - 120000).toISOString(), // 2 min ago
          custom_rakah_count: 4,
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Dhuhr'));

      await waitFor(() => {
        expect(mockSetRakahEstimate).toHaveBeenCalled();
      });

      const initialCallCount = mockSetRakahEstimate.mock.calls.length;

      act(() => {
        vi.advanceTimersByTime(10000);
      });

      await waitFor(() => {
        expect(mockSetRakahEstimate.mock.calls.length).toBeGreaterThan(initialCallCount);
      });
    }, 10000);

    it('should handle prayers without iqama', async () => {
      const now = Date.now();
      const mockPrayerTimes = createMockPrayerTimes({
        fajr: {
          name: 'Fajr',
          adhan: new Date(now - 600000).toISOString(),
          iqama: null, // No iqama time
          custom_rakah_count: 2,
        },
      });

      (useStore as ReturnType<typeof vi.fn>).mockReturnValue({
        currentMosque: { id: 'test', name: 'Test Mosque' },
        currentPrayerTimes: mockPrayerTimes,
        setRakahEstimate: mockSetRakahEstimate,
      });

      renderHook(() => useRakahEstimate('Fajr'));

      await waitFor(() => {
        expect(mockSetRakahEstimate).toHaveBeenCalledWith({
          status: 'not_available',
          total_rakah: 2,
          progress: 0,
          is_estimate: false,
          can_still_catch: false,
        });
      });
    }, 10000);
  });
});
