import { invoke } from '@tauri-apps/api/tauri';
import type {
  Mosque,
  NextPrayerResult,
  PrayerTimes,
  PrayerCountdown,
  RakahEstimate,
  TravelPrediction,
  ProviderInfo,
  ProviderTestResult,
  ProviderConfig,
  Settings,
} from '../types';

// Mosque commands
export const searchMosques = async (query: string, country?: string): Promise<{ mosques: Mosque[]; total: number }> => {
  return invoke('search_mosques', { query, country });
};

export const getFavoriteMosques = async (): Promise<Mosque[]> => {
  return invoke('get_favorite_mosques');
};

export const addFavoriteMosque = async (mosque: Mosque): Promise<void> => {
  return invoke('add_favorite_mosque', { mosque });
};

export const removeFavoriteMosque = async (mosqueId: string): Promise<void> => {
  return invoke('remove_favorite_mosque', { mosqueId });
};

export const saveSelectedMosque = async (mosque: Mosque): Promise<void> => {
  return invoke('save_selected_mosque', { mosque });
};

export const getSelectedMosque = async (): Promise<Mosque | null> => {
  return invoke('get_selected_mosque');
};

export const checkDatabaseHealth = async (): Promise<{
  db_path: string;
  file_exists: boolean;
  file_size_bytes: number;
  app_dir_exists: boolean;
  app_dir_path: string;
}> => {
  return invoke('check_database_health');
};

export const getMosqueDetails = async (mosqueId: string): Promise<Mosque | null> => {
  return invoke('get_mosque_details', { mosqueId });
};

export const getPrayerTimesForMosque = async (mosqueId: string, country?: string, date?: string): Promise<PrayerTimes> => {
  return invoke('get_prayer_times_for_mosque', { mosqueId, country, date });
};

export const fetchPrayerTimesForDate = async (mawaqitUrl: string, date: string): Promise<PrayerTimes> => {
  return invoke('fetch_prayer_times_for_date', { mawaqitUrl, date });
};

export const getActiveProvider = async (): Promise<ProviderInfo | null> => {
  return invoke('get_active_provider');
};

export const getAvailableProviders = async (): Promise<ProviderInfo[]> => {
  return invoke('get_available_providers');
};

// Prayer commands
export const getNextPrayer = async (mosqueId: string): Promise<NextPrayerResult> => {
  return invoke('get_next_prayer', { mosqueId });
};

export const getPrayerTimes = async (mosqueId: string): Promise<PrayerTimes> => {
  return invoke('get_prayer_times', { mosqueId });
};

export const getAllCountdowns = async (mosqueId: string): Promise<PrayerCountdown[]> => {
  return invoke('get_all_countdowns', { mosqueId });
};

export const estimateRakah = async (mosqueId: string, prayerName: string): Promise<RakahEstimate> => {
  return invoke('estimate_rakah', { mosqueId, prayerName });
};

export const calculateTravelPrediction = async (
  mosqueId: string,
  prayerName: string,
  travelTimeSeconds: number
): Promise<TravelPrediction> => {
  return invoke('calculate_travel_prediction', { mosqueId, prayerName, travelTimeSeconds });
};

export const getCountdown = async (mosqueId: string, prayerName: string): Promise<number | null> => {
  return invoke('get_countdown', { mosqueId, prayerName });
};

export const formatDuration = async (seconds: number): Promise<string> => {
  return invoke('format_duration', { seconds });
};

// Provider commands
export const testProviderConnection = async (
  providerId: string,
  config: Record<string, unknown>
): Promise<ProviderTestResult> => {
  return invoke('test_provider_connection', { providerId, config });
};

// Settings commands
export const getSetting = async (key: string): Promise<string | null> => {
  return invoke('get_setting', { key });
};

export const setSetting = async (key: string, value: string): Promise<void> => {
  return invoke('set_setting', { key, value });
};

export const getProviderConfig = async (providerId: string): Promise<ProviderConfig | null> => {
  return invoke('get_provider_config', { providerId });
};

export const saveProviderConfig = async (config: ProviderConfig): Promise<void> => {
  return invoke('save_provider_config', { config });
};

export const getAllSettings = async (): Promise<Settings> => {
  return invoke('get_all_settings');
};

export const saveAllSettings = async (settings: Settings): Promise<void> => {
  return invoke('save_all_settings', { settings });
};
