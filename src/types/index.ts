export interface Prayer {
  name: string;
  adhan: string;
  iqama?: string;
  custom_rakah_count?: number;
}

export interface PrayerTimes {
  date: string;
  fajr: Prayer;
  dhuhr: Prayer;
  asr: Prayer;
  maghrib: Prayer;
  isha: Prayer;
  jumuah?: Prayer;
  mosque_id?: string;
  mosque_name?: string;
  cached_at?: string;
}

export interface Mosque {
  id: string;
  name: string;
  address?: string;
  city?: string;
  country?: string;
  latitude?: number;
  longitude?: number;
  is_favorite: boolean;
  last_accessed?: string;
}

export interface NextPrayerResult {
  prayer: Prayer;
  time_until_adhan_secs: number;
  time_until_iqama_secs?: number;
  is_tomorrow: boolean;
}

export interface RakahEstimate {
  status: 'not_started' | 'in_progress' | 'likely_finished' | 'recently_finished' | 'not_available';
  current_rakah?: number;
  total_rakah: number;
  elapsed_secs?: number;
  remaining_secs?: number;
  progress: number;
  is_estimate: boolean;
  /** Minutes since prayer ended (only for recently_finished status) */
  ended_minutes_ago?: number;
  /** Whether it's still possible to catch the prayer (within catch-up window) */
  can_still_catch: boolean;
}

export interface TravelPrediction {
  recommended_leave_time: string;
  arrival_time: string;
  arrival_rakah?: number;
  arrival_status: string;
  should_leave_now: boolean;
  time_until_leave_secs?: number;
  is_late: boolean;
}

export interface PrayerCountdown {
  prayer_name: string;
  adhan_time: string;
  iqama_time?: string;
  time_until_adhan_secs: number;
  time_until_iqama_secs?: number;
  is_active: boolean;
}

export interface ConfigField {
  key: string;
  label: string;
  field_type: 'string' | 'password' | 'number' | 'boolean' | 'url' | 'select';
  required: boolean;
  description?: string;
  default_value?: string;
  options?: string[];
}

export interface ProviderInfo {
  id: string;
  name: string;
  description: string;
  config_schema: ConfigField[];
}

export interface ProviderTestResult {
  success: boolean;
  message: string;
  latency_ms?: number;
}

export interface ProviderConfig {
  provider_id: string;
  settings: Record<string, unknown>;
}

export interface Settings {
  theme: 'light' | 'dark';
  language: string;
  notification_enabled: boolean;
}
