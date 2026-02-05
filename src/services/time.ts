import { format } from 'date-fns';

// Format countdown with hours, minutes, seconds
export const formatCountdown = (seconds: number): string => {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes.toString().padStart(2, '0')}m ${secs.toString().padStart(2, '0')}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs.toString().padStart(2, '0')}s`;
  } else {
    return `${secs}s`;
  }
};

// Format time for display (e.g., "5:30 AM")
export const formatTime = (dateStr: string): string => {
  const date = new Date(dateStr);
  return format(date, 'h:mm a');
};

// Format time until (shorter format, no seconds)
export const formatTimeUntil = (seconds: number): string => {
  if (seconds <= 0) return 'Now';
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  return `${minutes}m`;
};

// Format duration with appropriate precision
export const formatDuration = (seconds: number): string => {
  if (seconds <= 0) return 'Now';
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
};

// Format for compact display (no seconds)
export const formatCompact = (seconds: number): string => {
  if (seconds <= 0) return 'Now';
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  
  if (hours > 0) {
    return `${hours}h ${minutes.toString().padStart(2, '0')}m`;
  }
  return `${minutes.toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
};

// Prayer icons
export const getPrayerIcon = (prayerName: string): string => {
  const icons: Record<string, string> = {
    Fajr: '🌅',
    Dhuhr: '☀️',
    Asr: '🌤️',
    Maghrib: '🌇',
    Isha: '🌙',
    Jumuah: '🕌',
  };
  return icons[prayerName] || '🕐';
};

// Prayer gradient colors
export const getPrayerColor = (prayerName: string): string => {
  const colors: Record<string, string> = {
    Fajr: 'from-blue-400 to-indigo-500',
    Dhuhr: 'from-yellow-400 to-orange-500',
    Asr: 'from-orange-400 to-amber-500',
    Maghrib: 'from-red-400 to-pink-500',
    Isha: 'from-indigo-400 to-purple-500',
    Jumuah: 'from-emerald-400 to-green-500',
  };
  return colors[prayerName] || 'from-gray-400 to-gray-500';
};

// Calculate time remaining until a specific prayer time
export const getTimeRemaining = (targetTime: string): number => {
  const target = new Date(targetTime);
  const now = new Date();
  return Math.floor((target.getTime() - now.getTime()) / 1000);
};

// Check if a prayer time has passed
export const hasPrayerPassed = (prayerTime: string): boolean => {
  return getTimeRemaining(prayerTime) < 0;
};

// Get next occurrence of a prayer (handles wrap-around to next day)
export const getNextPrayerTime = (prayerTimes: { name: string; time: string }[]): { name: string; time: string; secondsUntil: number } | null => {
  const now = new Date();
  let nextPrayer = null;
  let minDiff = Infinity;
  
  for (const prayer of prayerTimes) {
    const prayerTime = new Date(prayer.time);
    const diff = prayerTime.getTime() - now.getTime();
    
    if (diff > 0 && diff < minDiff) {
      minDiff = diff;
      nextPrayer = {
        name: prayer.name,
        time: prayer.time,
        secondsUntil: Math.floor(diff / 1000),
      };
    }
  }
  
  return nextPrayer;
};

// Get urgency color based on time remaining
export const getUrgencyColor = (seconds: number): string => {
  if (seconds <= 0) return 'text-gray-500';
  if (seconds < 300) return 'text-red-400';      // < 5 min
  if (seconds < 900) return 'text-orange-400';   // < 15 min
  if (seconds < 1800) return 'text-yellow-400';  // < 30 min
  return 'text-emerald-400';
};

// Get urgency background color
export const getUrgencyBg = (seconds: number): string => {
  if (seconds <= 0) return 'bg-gray-500/20';
  if (seconds < 300) return 'bg-red-500/20 border-red-500/30';
  if (seconds < 900) return 'bg-orange-500/20 border-orange-500/30';
  if (seconds < 1800) return 'bg-yellow-500/20 border-yellow-500/30';
  return 'bg-emerald-500/20 border-emerald-500/30';
};

// Format for Live Timer display (large format)
export const formatLiveTimer = (seconds: number): { hours: string; minutes: string; seconds: string; display: string } => {
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;
  
  const hours = hrs.toString().padStart(2, '0');
  const minutes = mins.toString().padStart(2, '0');
  const secondsStr = secs.toString().padStart(2, '0');
  
  let display;
  if (hrs > 0) {
    display = `${hours}:${minutes}:${secondsStr}`;
  } else {
    display = `${minutes}:${secondsStr}`;
  }
  
  return { hours, minutes: minutes, seconds: secondsStr, display };
};

// Check if prayer is currently active (between adhan and iqama)
export const isPrayerActive = (adhanTime: string, iqamaTime: string | null): boolean => {
  if (!iqamaTime) return false;
  const now = Date.now();
  const adhan = new Date(adhanTime).getTime();
  const iqama = new Date(iqamaTime).getTime();
  return now >= adhan && now < iqama;
};

// Check if prayer is in progress (after iqama)
export const isPrayerInProgress = (iqamaTime: string | null, durationMinutes: number = 15): boolean => {
  if (!iqamaTime) return false;
  const now = Date.now();
  const iqama = new Date(iqamaTime).getTime();
  const end = iqama + (durationMinutes * 60 * 1000);
  return now >= iqama && now < end;
};
