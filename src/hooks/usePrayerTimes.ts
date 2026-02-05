import { useEffect, useState, useCallback } from 'react';
import { useStore } from './useStore';
import * as tauri from '../services/tauri';

export const usePrayerTimes = () => {
  const { 
    currentMosque, 
    currentPrayerTimes,
    setNextPrayer, 
    setCountdowns, 
    setError 
  } = useStore();
  const [refreshInterval, setRefreshInterval] = useState<ReturnType<typeof setInterval> | null>(null);

  const refreshPrayerData = useCallback(async () => {
    if (!currentMosque || !currentPrayerTimes) return;

    try {
      // Calculate next prayer from the current prayer times
      const prayers = [
        currentPrayerTimes.fajr,
        currentPrayerTimes.dhuhr,
        currentPrayerTimes.asr,
        currentPrayerTimes.maghrib,
        currentPrayerTimes.isha,
      ];

      const now = new Date();
      
      // Find next prayer
      let nextPrayer = null;
      let minDiff = Infinity;
      
      for (const prayer of prayers) {
        const prayerTime = new Date(prayer.adhan);
        const diff = prayerTime.getTime() - now.getTime();
        
        if (diff > 0 && diff < minDiff) {
          minDiff = diff;
          nextPrayer = prayer;
        }
      }

      // If no future prayer today, use tomorrow's Fajr
      if (!nextPrayer) {
        const tomorrowFajr = new Date(currentPrayerTimes.fajr.adhan);
        tomorrowFajr.setDate(tomorrowFajr.getDate() + 1);
        nextPrayer = {
          ...currentPrayerTimes.fajr,
          adhan: tomorrowFajr.toISOString(),
        };
      }

      // Calculate countdowns for all prayers
      const countdowns = prayers.map((prayer) => {
        const prayerTime = new Date(prayer.adhan);
        const iqamaTime = prayer.iqama ? new Date(prayer.iqama) : null;
        const diff = prayerTime.getTime() - now.getTime();
        const iqamaDiff = iqamaTime ? iqamaTime.getTime() - now.getTime() : null;
        
        return {
          prayer_name: prayer.name,
          adhan_time: prayer.adhan,
          iqama_time: prayer.iqama,
          time_until_adhan_secs: Math.max(0, Math.floor(diff / 1000)),
          time_until_iqama_secs: iqamaDiff ? Math.max(0, Math.floor(iqamaDiff / 1000)) : undefined,
          is_active: Boolean(diff <= 0 && iqamaDiff && iqamaDiff > 0),
        };
      });

      // Calculate time until next prayer
      const nextPrayerTime = new Date(nextPrayer.adhan);
      const timeUntilAdhan = Math.floor((nextPrayerTime.getTime() - now.getTime()) / 1000);
      
      const nextIqamaTime = nextPrayer.iqama ? new Date(nextPrayer.iqama) : null;
      const timeUntilIqama = nextIqamaTime 
        ? Math.floor((nextIqamaTime.getTime() - now.getTime()) / 1000)
        : undefined;

      setNextPrayer({
        prayer: nextPrayer,
        time_until_adhan_secs: timeUntilAdhan,
        time_until_iqama_secs: timeUntilIqama,
        is_tomorrow: nextPrayer.name === currentPrayerTimes.fajr.name && timeUntilAdhan > 86400 / 2,
      });

      setCountdowns(countdowns);
    } catch (err) {
      console.error('Failed to refresh prayer data:', err);
      setError(err instanceof Error ? err.message : 'Failed to refresh prayer data');
    }
  }, [currentMosque, currentPrayerTimes, setNextPrayer, setCountdowns, setError]);

  useEffect(() => {
    if (!currentMosque || !currentPrayerTimes) {
      if (refreshInterval) {
        clearInterval(refreshInterval);
        setRefreshInterval(null);
      }
      return;
    }

    refreshPrayerData();

    // Refresh every second for live countdown
    const interval = setInterval(refreshPrayerData, 1000);
    setRefreshInterval(interval);

    return () => {
      clearInterval(interval);
    };
  }, [currentMosque, currentPrayerTimes, refreshPrayerData]);

  return { refreshPrayerData };
};

export const useRakahEstimate = (prayerName: string | null) => {
  const { currentMosque, currentPrayerTimes, setRakahEstimate } = useStore();

  useEffect(() => {
    if (!currentMosque || !prayerName || !currentPrayerTimes) return;

    const estimateRakah = async () => {
      try {
        // Find the current prayer
        const prayer = [
          currentPrayerTimes.fajr,
          currentPrayerTimes.dhuhr,
          currentPrayerTimes.asr,
          currentPrayerTimes.maghrib,
          currentPrayerTimes.isha,
        ].find(p => p.name === prayerName);

        if (!prayer) return;

        // Calculate estimate locally
        const now = new Date();
        const iqamaTime = prayer.iqama ? new Date(prayer.iqama) : null;
        
        if (!iqamaTime) {
          setRakahEstimate({
            status: 'not_available',
            total_rakah: prayer.name === 'Fajr' ? 2 : prayer.name === 'Maghrib' ? 3 : 4,
            progress: 0,
            is_estimate: false,
            can_still_catch: false,
          });
          return;
        }

        const elapsed = now.getTime() - iqamaTime.getTime();
        const elapsedSeconds = Math.floor(elapsed / 1000);
        
        // Configuration
        const rakahDuration = 144; // 2.4 minutes in seconds
        const totalRakah = prayer.name === 'Fajr' ? 2 : prayer.name === 'Maghrib' ? 3 : 4;
        const postPrayerDisplayMinutes = 28; // Show "ended" for 28 minutes
        const catchUpMinutes = 3; // ±3 min window to catch prayer
        
        const estimatedDurationSeconds = totalRakah * rakahDuration;
        const prayerEndSeconds = estimatedDurationSeconds;
        const postPrayerWindowSeconds = postPrayerDisplayMinutes * 60;
        const catchUpWindowSeconds = catchUpMinutes * 60;
        
        // Not started yet
        if (elapsed < 0) {
          setRakahEstimate({
            status: 'not_started',
            total_rakah: totalRakah,
            remaining_secs: Math.floor(-elapsed / 1000),
            progress: 0,
            is_estimate: true,
            can_still_catch: false,
          });
          return;
        }
        
        // Prayer ended, but within post-prayer display window (28 min)
        if (elapsedSeconds > prayerEndSeconds && elapsedSeconds <= prayerEndSeconds + postPrayerWindowSeconds) {
          const endedMinutesAgo = Math.ceil((elapsedSeconds - prayerEndSeconds) / 60);
          const canStillCatch = elapsedSeconds <= prayerEndSeconds + catchUpWindowSeconds;
          
          setRakahEstimate({
            status: 'recently_finished',
            current_rakah: totalRakah,
            total_rakah: totalRakah,
            elapsed_secs: elapsedSeconds,
            progress: 1.0,
            is_estimate: true,
            ended_minutes_ago: endedMinutesAgo,
            can_still_catch: canStillCatch,
          });
          return;
        }
        
        // Beyond post-prayer window - don't show live status
        if (elapsedSeconds > prayerEndSeconds + postPrayerWindowSeconds) {
          setRakahEstimate({
            status: 'likely_finished',
            current_rakah: totalRakah,
            total_rakah: totalRakah,
            elapsed_secs: elapsedSeconds,
            progress: 1.0,
            is_estimate: true,
            can_still_catch: false,
          });
          return;
        }
        
        // In progress - calculate rakah
        const rakahIndex = Math.floor(elapsedSeconds / rakahDuration) + 1;
        const currentRakah = Math.min(rakahIndex, totalRakah);
        const progress = Math.min(1.0, elapsedSeconds / estimatedDurationSeconds);

        setRakahEstimate({
          status: 'in_progress',
          current_rakah: currentRakah,
          total_rakah: totalRakah,
          elapsed_secs: elapsedSeconds,
          progress: progress,
          is_estimate: true,
          can_still_catch: false,
        });
      } catch (err) {
        console.error('Failed to estimate rakah:', err);
      }
    };

    estimateRakah();
    const interval = setInterval(estimateRakah, 10000); // Update every 10 seconds

    return () => clearInterval(interval);
  }, [currentMosque, currentPrayerTimes, prayerName, setRakahEstimate]);
};

export const useFavoriteMosques = () => {
  const { favoriteMosques, setFavoriteMosques, setIsLoading, setError } = useStore();

  const loadFavorites = useCallback(async () => {
    setIsLoading(true);
    try {
      const mosques = await tauri.getFavoriteMosques();
      setFavoriteMosques(mosques);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load favorites');
    } finally {
      setIsLoading(false);
    }
  }, [setFavoriteMosques, setIsLoading, setError]);

  const addFavorite = async (mosque: { id: string; name: string; address?: string }) => {
    try {
      await tauri.addFavoriteMosque({
        ...mosque,
        is_favorite: true,
      });
      await loadFavorites();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to add favorite');
    }
  };

  const removeFavorite = async (mosqueId: string) => {
    try {
      await tauri.removeFavoriteMosque(mosqueId);
      await loadFavorites();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to remove favorite');
    }
  };

  useEffect(() => {
    loadFavorites();
  }, [loadFavorites]);

  return { favoriteMosques, loadFavorites, addFavorite, removeFavorite };
};
