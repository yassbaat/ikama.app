import { useEffect, useState, useCallback, useRef } from 'react';

interface TimerState {
  hours: number;
  minutes: number;
  seconds: number;
  totalSeconds: number;
  isExpired: boolean;
}

export const useLiveTimer = (targetTime: string | null, interval: number = 1000) => {
  const [timerState, setTimerState] = useState<TimerState | null>(null);
  const animationFrameRef = useRef<number | null>(null);
  const lastUpdateRef = useRef<number>(0);

  const calculateTimeRemaining = useCallback(() => {
    if (!targetTime) return null;
    
    const target = new Date(targetTime).getTime();
    const now = Date.now();
    const diff = target - now;
    
    if (diff <= 0) {
      return {
        hours: 0,
        minutes: 0,
        seconds: 0,
        totalSeconds: 0,
        isExpired: true,
      };
    }
    
    const totalSeconds = Math.floor(diff / 1000);
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;
    
    return {
      hours,
      minutes,
      seconds,
      totalSeconds,
      isExpired: false,
    };
  }, [targetTime]);

  useEffect(() => {
    if (!targetTime) {
      setTimerState(null);
      return;
    }

    // Use requestAnimationFrame for smoother updates when tab is active
    const updateTimer = (timestamp: number) => {
      // Only update state at the specified interval to avoid excessive re-renders
      if (timestamp - lastUpdateRef.current >= interval) {
        const newState = calculateTimeRemaining();
        setTimerState(newState);
        lastUpdateRef.current = timestamp;
        
        // Stop animation frame if timer expired
        if (newState?.isExpired) {
          return;
        }
      }
      
      animationFrameRef.current = requestAnimationFrame(updateTimer);
    };

    // Initial calculation
    setTimerState(calculateTimeRemaining());
    
    // Start animation frame
    animationFrameRef.current = requestAnimationFrame(updateTimer);

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [targetTime, interval, calculateTimeRemaining]);

  return timerState;
};

// Hook for multiple timers (for prayer list)
export const useMultipleTimers = (targetTimes: Record<string, string | null>, interval: number = 1000) => {
  const [timers, setTimers] = useState<Record<string, TimerState>>({});
  const animationFrameRef = useRef<number | null>(null);
  const lastUpdateRef = useRef<number>(0);

  const calculateAllTimers = useCallback(() => {
    const now = Date.now();
    const newTimers: Record<string, TimerState> = {};
    
    Object.entries(targetTimes).forEach(([key, targetTime]) => {
      if (!targetTime) return;
      
      const target = new Date(targetTime).getTime();
      const diff = target - now;
      
      if (diff <= 0) {
        newTimers[key] = {
          hours: 0,
          minutes: 0,
          seconds: 0,
          totalSeconds: 0,
          isExpired: true,
        };
      } else {
        const totalSeconds = Math.floor(diff / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        
        newTimers[key] = {
          hours,
          minutes,
          seconds,
          totalSeconds,
          isExpired: false,
        };
      }
    });
    
    return newTimers;
  }, [targetTimes]);

  useEffect(() => {
    const updateTimers = (timestamp: number) => {
      if (timestamp - lastUpdateRef.current >= interval) {
        setTimers(calculateAllTimers());
        lastUpdateRef.current = timestamp;
      }
      
      animationFrameRef.current = requestAnimationFrame(updateTimers);
    };

    // Initial calculation
    setTimers(calculateAllTimers());
    
    animationFrameRef.current = requestAnimationFrame(updateTimers);

    return () => {
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [targetTimes, interval, calculateAllTimers]);

  return timers;
};

// Hook for relative time display (e.g., "2 minutes ago", "in 3 hours")
export const useRelativeTime = (targetTime: string | null) => {
  const [relativeTime, setRelativeTime] = useState<string>('');
  
  useEffect(() => {
    if (!targetTime) {
      setRelativeTime('');
      return;
    }

    const updateRelativeTime = () => {
      const target = new Date(targetTime).getTime();
      const now = Date.now();
      const diff = target - now;
      const absDiff = Math.abs(diff);
      
      const seconds = Math.floor(absDiff / 1000);
      const minutes = Math.floor(seconds / 60);
      const hours = Math.floor(minutes / 60);
      const days = Math.floor(hours / 24);
      
      if (diff > 0) {
        // Future
        if (days > 0) setRelativeTime(`in ${days} day${days > 1 ? 's' : ''}`);
        else if (hours > 0) setRelativeTime(`in ${hours} hour${hours > 1 ? 's' : ''}`);
        else if (minutes > 0) setRelativeTime(`in ${minutes} minute${minutes > 1 ? 's' : ''}`);
        else setRelativeTime('in a few seconds');
      } else {
        // Past
        if (days > 0) setRelativeTime(`${days} day${days > 1 ? 's' : ''} ago`);
        else if (hours > 0) setRelativeTime(`${hours} hour${hours > 1 ? 's' : ''} ago`);
        else if (minutes > 0) setRelativeTime(`${minutes} minute${minutes > 1 ? 's' : ''} ago`);
        else setRelativeTime('just now');
      }
    };

    updateRelativeTime();
    const interval = setInterval(updateRelativeTime, 60000); // Update every minute
    
    return () => clearInterval(interval);
  }, [targetTime]);
  
  return relativeTime;
};

// Format timer for display with leading zeros
export const formatTimer = (timer: TimerState | null, showSeconds: boolean = true): string => {
  if (!timer) return '--:--';
  
  const { hours, minutes, seconds } = timer;
  
  if (hours > 0) {
    return showSeconds 
      ? `${hours}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
      : `${hours}h ${minutes}m`;
  }
  
  return showSeconds
    ? `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
    : `${minutes}m`;
};

// Get timer urgency level for styling
export const getTimerUrgency = (totalSeconds: number): 'normal' | 'soon' | 'urgent' | 'expired' => {
  if (totalSeconds <= 0) return 'expired';
  if (totalSeconds < 300) return 'urgent'; // Less than 5 minutes
  if (totalSeconds < 900) return 'soon';   // Less than 15 minutes
  return 'normal';
};
