/**
 * Night Prayer (Tahajjud/Qiyam) calculation
 * 
 * The last third of the night is calculated from Maghrib to Fajr,
 * divided into three equal parts. The last third is the optimal
 * time for night prayer.
 */

export interface NightPrayerInfo {
  /** Start time of the last third of the night (ISO string) */
  startTime: string;
  /** End time (Fajr time) */
  endTime: string;
  /** Duration of the last third in seconds */
  durationSeconds: number;
  /** Whether we're currently in the last third */
  isActive: boolean;
  /** Time remaining until last third starts (null if already started) */
  timeUntilStartSeconds: number | null;
  /** Time remaining until Fajr (null if Fajr passed) */
  timeUntilFajrSeconds: number | null;
  /** Progress through the last third (0-1) */
  progress: number;
  /** Formatted display text */
  displayText: string;
}

/**
 * Calculate the last third of the night
 * @param maghribTime - Maghrib prayer time (ISO string)
 * @param fajrTime - Fajr prayer time (ISO string)
 * @param now - Current time (defaults to now)
 */
export function calculateNightPrayer(
  maghribTime: string,
  fajrTime: string,
  now: Date = new Date()
): NightPrayerInfo | null {
  const maghrib = new Date(maghribTime).getTime();
  const fajr = new Date(fajrTime).getTime();
  const current = now.getTime();

  // Validate times
  if (isNaN(maghrib) || isNaN(fajr)) {
    return null;
  }

  // Calculate total night duration
  const nightDuration = fajr - maghrib;
  
  if (nightDuration <= 0) {
    return null;
  }

  // Last third starts after 2/3 of the night
  const lastThirdDuration = nightDuration / 3;
  const lastThirdStart = maghrib + (lastThirdDuration * 2);

  // Check if we're in the night period
  const isInNightPeriod = current >= maghrib && current < fajr;
  const isInLastThird = current >= lastThirdStart && current < fajr;
  
  // Calculate time until last third starts
  const timeUntilStart = lastThirdStart - current;
  const timeUntilStartSeconds = timeUntilStart > 0 ? Math.floor(timeUntilStart / 1000) : null;

  // Calculate time until Fajr
  const timeUntilFajr = fajr - current;
  const timeUntilFajrSeconds = timeUntilFajr > 0 ? Math.floor(timeUntilFajr / 1000) : null;

  // Calculate progress through last third
  let progress = 0;
  if (current >= lastThirdStart) {
    const elapsedInLastThird = current - lastThirdStart;
    progress = Math.min(1, elapsedInLastThird / lastThirdDuration);
  }

  // Generate display text
  let displayText = '';
  if (isInLastThird) {
    displayText = 'Last third of the night - Best time for night prayer';
  } else if (isInNightPeriod) {
    const hoursUntil = Math.ceil(timeUntilStartSeconds! / 3600);
    displayText = `Last third starts in ${hoursUntil} hour${hoursUntil > 1 ? 's' : ''}`;
  } else {
    displayText = 'Night prayer time has passed';
  }

  return {
    startTime: new Date(lastThirdStart).toISOString(),
    endTime: fajrTime,
    durationSeconds: Math.floor(lastThirdDuration / 1000),
    isActive: isInLastThird,
    timeUntilStartSeconds,
    timeUntilFajrSeconds,
    progress,
    displayText,
  };
}

/**
 * Format duration for display (hours and minutes)
 */
export function formatDuration(seconds: number): string {
  if (seconds <= 0) return '0m';
  
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  
  if (hours > 0 && minutes > 0) {
    return `${hours}h ${minutes}m`;
  } else if (hours > 0) {
    return `${hours}h`;
  } else {
    return `${minutes}m`;
  }
}

/**
 * Format time for display (HH:MM AM/PM)
 */
export function formatTime(isoString: string): string {
  const date = new Date(isoString);
  return date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
  });
}

/**
 * Check if we're currently in the night period (after Isha/Maghrib, before Fajr)
 */
export function isNightPeriod(
  maghribTime: string,
  fajrTime: string,
  now: Date = new Date()
): boolean {
  const maghrib = new Date(maghribTime).getTime();
  const fajr = new Date(fajrTime).getTime();
  const current = now.getTime();

  return current >= maghrib && current < fajr;
}

/**
 * Check if Isha has passed and we're waiting for Fajr
 */
export function isBetweenIshaAndFajr(
  ishaTime: string,
  fajrTime: string,
  now: Date = new Date()
): boolean {
  const isha = new Date(ishaTime).getTime();
  const fajr = new Date(fajrTime).getTime();
  const current = now.getTime();

  return current >= isha && current < fajr;
}
