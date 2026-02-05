import { create } from 'zustand';
import type { Mosque, NextPrayerResult, PrayerCountdown, RakahEstimate, PrayerTimes, Settings, Prayer } from '../types';

interface AppState {
  // Current mosque
  currentMosque: Mosque | null;
  setCurrentMosque: (mosque: Mosque | null) => void;

  // Prayer data
  currentPrayerTimes: PrayerTimes | null;
  setCurrentPrayerTimes: (times: PrayerTimes | null) => void;

  // Selected date for prayer times
  selectedDate: string;
  setSelectedDate: (date: string) => void;
  viewingDate: Date;
  setViewingDate: (date: Date) => void;

  // Calendar view state
  isCalendarExpanded: boolean;
  setIsCalendarExpanded: (expanded: boolean) => void;

  // Selected prayer (for showing details)
  selectedPrayer: Prayer | null;
  setSelectedPrayer: (prayer: Prayer | null) => void;
  showPrayerDetails: boolean;
  setShowPrayerDetails: (show: boolean) => void;

  // Next prayer
  nextPrayer: NextPrayerResult | null;
  setNextPrayer: (prayer: NextPrayerResult | null) => void;

  // Countdowns
  countdowns: PrayerCountdown[];
  setCountdowns: (countdowns: PrayerCountdown[]) => void;

  // Rakah estimation
  rakahEstimate: RakahEstimate | null;
  setRakahEstimate: (estimate: RakahEstimate | null) => void;

  // Favorites
  favoriteMosques: Mosque[];
  setFavoriteMosques: (mosques: Mosque[]) => void;

  // Settings
  settings: Settings;
  setSettings: (settings: Settings) => void;

  // Notification settings
  adhanNotifications: boolean;
  setAdhanNotifications: (enabled: boolean) => void;
  iqamahNotifications: boolean;
  setIqamahNotifications: (enabled: boolean) => void;

  // Night prayer settings
  showNightPrayer: boolean;
  setShowNightPrayer: (enabled: boolean) => void;

  // UI state
  isLoading: boolean;
  setIsLoading: (loading: boolean) => void;
  error: string | null;
  setError: (error: string | null) => void;
  clearError: () => void;
}

export const useStore = create<AppState>((set) => ({
  currentMosque: null,
  setCurrentMosque: (mosque) => set({ currentMosque: mosque }),

  currentPrayerTimes: null,
  setCurrentPrayerTimes: (times) => set({ currentPrayerTimes: times }),

  selectedDate: new Date().toISOString().split('T')[0], // YYYY-MM-DD format
  setSelectedDate: (date) => set({ selectedDate: date }),
  viewingDate: new Date(),
  setViewingDate: (date) => set({ viewingDate: date }),

  isCalendarExpanded: false,
  setIsCalendarExpanded: (expanded) => set({ isCalendarExpanded: expanded }),

  selectedPrayer: null,
  setSelectedPrayer: (prayer) => set({ selectedPrayer: prayer }),
  showPrayerDetails: false,
  setShowPrayerDetails: (show) => set({ showPrayerDetails: show }),

  nextPrayer: null,
  setNextPrayer: (prayer) => set({ nextPrayer: prayer }),

  countdowns: [],
  setCountdowns: (countdowns) => set({ countdowns }),

  rakahEstimate: null,
  setRakahEstimate: (estimate) => set({ rakahEstimate: estimate }),

  favoriteMosques: [],
  setFavoriteMosques: (mosques) => set({ favoriteMosques: mosques }),

  settings: {
    theme: 'dark',
    language: 'en',
    notification_enabled: true,
  },
  setSettings: (settings) => set({ settings }),

  adhanNotifications: true,
  setAdhanNotifications: (enabled) => set({ adhanNotifications: enabled }),
  iqamahNotifications: true,
  setIqamahNotifications: (enabled) => set({ iqamahNotifications: enabled }),

  showNightPrayer: true,
  setShowNightPrayer: (enabled) => set({ showNightPrayer: enabled }),

  isLoading: false,
  setIsLoading: (loading) => set({ isLoading: loading }),
  error: null,
  setError: (error) => set({ error }),
  clearError: () => set({ error: null }),
}));
