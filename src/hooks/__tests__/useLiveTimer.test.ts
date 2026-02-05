import { renderHook, act, waitFor } from '@testing-library/react';
import { useLiveTimer, useMultipleTimers, useRelativeTime, formatTimer, getTimerUrgency } from '../useLiveTimer';
import { vi, describe, it, expect, beforeEach, afterEach } from 'vitest';

describe('useLiveTimer', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should initialize with correct time remaining', () => {
    const targetTime = new Date(Date.now() + 60000).toISOString(); // 1 minute from now
    
    const { result } = renderHook(() => useLiveTimer(targetTime));
    
    expect(result.current).not.toBeNull();
    expect(result.current?.totalSeconds).toBeGreaterThan(55);
    expect(result.current?.totalSeconds).toBeLessThanOrEqual(60);
    expect(result.current?.isExpired).toBe(false);
  });

  it('should update timer every second', async () => {
    const targetTime = new Date(Date.now() + 5000).toISOString(); // 5 seconds from now
    
    const { result } = renderHook(() => useLiveTimer(targetTime, 1000));
    
    const initialSeconds = result.current?.totalSeconds || 0;
    
    act(() => {
      vi.advanceTimersByTime(1000);
    });

    await waitFor(() => {
      expect(result.current?.totalSeconds).toBe(initialSeconds - 1);
    });
  });

  it('should mark as expired when time runs out', async () => {
    const targetTime = new Date(Date.now() + 1000).toISOString(); // 1 second from now
    
    const { result } = renderHook(() => useLiveTimer(targetTime, 100));
    
    act(() => {
      vi.advanceTimersByTime(1100);
    });

    await waitFor(() => {
      expect(result.current?.isExpired).toBe(true);
      expect(result.current?.totalSeconds).toBe(0);
    });
  });

  it('should return null when targetTime is null', () => {
    const { result } = renderHook(() => useLiveTimer(null));
    
    expect(result.current).toBeNull();
  });

  it('should calculate hours, minutes, seconds correctly', () => {
    const targetTime = new Date(Date.now() + 3665000).toISOString(); // 1h 1m 5s from now
    
    const { result } = renderHook(() => useLiveTimer(targetTime));
    
    expect(result.current?.hours).toBe(1);
    expect(result.current?.minutes).toBe(1);
    expect(result.current?.seconds).toBeGreaterThanOrEqual(0);
    expect(result.current?.seconds).toBeLessThanOrEqual(5);
  });
});

describe('useMultipleTimers', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('should track multiple timers', () => {
    const targetTimes = {
      fajr: new Date(Date.now() + 3600000).toISOString(),    // 1 hour
      dhuhr: new Date(Date.now() + 7200000).toISOString(),   // 2 hours
    };
    
    const { result } = renderHook(() => useMultipleTimers(targetTimes));
    
    expect(result.current.fajr).toBeDefined();
    expect(result.current.dhuhr).toBeDefined();
    expect(result.current.fajr.totalSeconds).toBeGreaterThan(3500);
    expect(result.current.dhuhr.totalSeconds).toBeGreaterThan(7100);
  });

  it('should update all timers', async () => {
    const targetTimes = {
      prayer1: new Date(Date.now() + 60000).toISOString(),
      prayer2: new Date(Date.now() + 120000).toISOString(),
    };
    
    const { result } = renderHook(() => useMultipleTimers(targetTimes, 1000));
    
    const initial1 = result.current.prayer1.totalSeconds;
    const initial2 = result.current.prayer2.totalSeconds;
    
    act(() => {
      vi.advanceTimersByTime(1000);
    });

    await waitFor(() => {
      expect(result.current.prayer1.totalSeconds).toBe(initial1 - 1);
      expect(result.current.prayer2.totalSeconds).toBe(initial2 - 1);
    });
  });
});

describe('useRelativeTime', () => {
  it('should show future time correctly', () => {
    const targetTime = new Date(Date.now() + 3600000).toISOString(); // 1 hour from now
    
    const { result } = renderHook(() => useRelativeTime(targetTime));
    
    expect(result.current).toContain('in');
    expect(result.current.match(/hour|minutes/)).toBeTruthy();
  });

  it('should show past time correctly', () => {
    const targetTime = new Date(Date.now() - 300000).toISOString(); // 5 minutes ago
    
    const { result } = renderHook(() => useRelativeTime(targetTime));
    
    expect(result.current).toContain('ago');
    expect(result.current).toContain('minute');
  });

  it('should return empty string for null', () => {
    const { result } = renderHook(() => useRelativeTime(null));
    
    expect(result.current).toBe('');
  });
});

describe('formatTimer', () => {
  it('should format with hours, minutes, seconds', () => {
    const timer = { hours: 2, minutes: 30, seconds: 45, totalSeconds: 9045, isExpired: false };
    
    expect(formatTimer(timer, true)).toBe('2:30:45');
  });

  it('should format without seconds', () => {
    const timer = { hours: 1, minutes: 15, seconds: 30, totalSeconds: 4530, isExpired: false };
    
    expect(formatTimer(timer, false)).toBe('1h 15m');
  });

  it('should format minutes only', () => {
    const timer = { hours: 0, minutes: 45, seconds: 30, totalSeconds: 2730, isExpired: false };
    
    expect(formatTimer(timer, true)).toBe('45:30');
  });

  it('should return placeholder for null', () => {
    expect(formatTimer(null)).toBe('--:--');
  });
});

describe('getTimerUrgency', () => {
  it('should return expired for 0 or negative', () => {
    expect(getTimerUrgency(0)).toBe('expired');
    expect(getTimerUrgency(-1)).toBe('expired');
  });

  it('should return urgent for less than 5 minutes', () => {
    expect(getTimerUrgency(299)).toBe('urgent');
    expect(getTimerUrgency(300)).toBe('soon');
  });

  it('should return soon for less than 15 minutes', () => {
    expect(getTimerUrgency(899)).toBe('soon');
    expect(getTimerUrgency(900)).toBe('normal');
  });

  it('should return normal for more than 15 minutes', () => {
    expect(getTimerUrgency(3600)).toBe('normal');
    expect(getTimerUrgency(86400)).toBe('normal');
  });
});
