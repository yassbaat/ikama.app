use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Configuration for the PrayerEngine
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrayerEngineConfig {
    pub rakah_duration_seconds: i64,
    pub start_lag_seconds: i64,
    pub buffer_before_start_seconds: i64,
    pub grace_seconds: i64,
    /// How long to show "prayer ended" message after estimated end (default: 28 minutes)
    pub post_prayer_display_minutes: i64,
    /// Window where user might still catch the prayer after estimated end (default: 3 minutes)
    pub catch_up_minutes: i64,
    pub default_rakah_counts: HashMap<String, i32>,
}

impl Default for PrayerEngineConfig {
    fn default() -> Self {
        let mut default_rakah_counts = HashMap::new();
        default_rakah_counts.insert("Fajr".to_string(), 2);
        default_rakah_counts.insert("Dhuhr".to_string(), 4);
        default_rakah_counts.insert("Asr".to_string(), 4);
        default_rakah_counts.insert("Maghrib".to_string(), 3);
        default_rakah_counts.insert("Isha".to_string(), 4);
        default_rakah_counts.insert("Jumuah".to_string(), 2);

        Self {
            rakah_duration_seconds: 144, // 2.4 minutes
            start_lag_seconds: 0,
            buffer_before_start_seconds: 30,
            grace_seconds: 60,
            post_prayer_display_minutes: 28, // Show "ended" message for 28 minutes
            catch_up_minutes: 3,             // ±3 min window to still catch prayer
            default_rakah_counts,
        }
    }
}

/// Prayer data structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Prayer {
    pub name: String,
    pub adhan: DateTime<Utc>,
    pub iqama: Option<DateTime<Utc>>,
    pub custom_rakah_count: Option<i32>,
}

impl Prayer {
    pub fn has_iqama(&self) -> bool {
        self.iqama.is_some()
    }

    pub fn get_rakah_count(&self, defaults: &HashMap<String, i32>) -> i32 {
        self.custom_rakah_count
            .or_else(|| defaults.get(&self.name).copied())
            .unwrap_or(4)
    }
}

/// Prayer times for a day
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrayerTimes {
    pub date: DateTime<Utc>,
    pub fajr: Prayer,
    pub dhuhr: Prayer,
    pub asr: Prayer,
    pub maghrib: Prayer,
    pub isha: Prayer,
    pub jumuah: Option<Prayer>,
    pub mosque_id: Option<String>,
    pub mosque_name: Option<String>,
    pub cached_at: Option<DateTime<Utc>>,
}

impl PrayerTimes {
    pub fn all_prayers(&self) -> Vec<&Prayer> {
        vec![&self.fajr, &self.dhuhr, &self.asr, &self.maghrib, &self.isha]
    }

    pub fn get_prayer_by_name(&self, name: &str) -> Option<&Prayer> {
        match name {
            "Fajr" => Some(&self.fajr),
            "Dhuhr" => Some(&self.dhuhr),
            "Asr" => Some(&self.asr),
            "Maghrib" => Some(&self.maghrib),
            "Isha" => Some(&self.isha),
            "Jumuah" => self.jumuah.as_ref(),
            _ => None,
        }
    }
}

/// Result for next prayer calculation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NextPrayerResult {
    pub prayer: Prayer,
    pub time_until_adhan_secs: i64,
    pub time_until_iqama_secs: Option<i64>,
    pub is_tomorrow: bool,
}

impl NextPrayerResult {
    pub fn has_iqama(&self) -> bool {
        self.time_until_iqama_secs.is_some()
    }
}

/// Rakah estimation result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RakahEstimate {
    pub status: String, // 'not_started', 'in_progress', 'likely_finished', 'recently_finished', 'not_available'
    pub current_rakah: Option<i32>,
    pub total_rakah: i32,
    pub elapsed_secs: Option<i64>,
    pub remaining_secs: Option<i64>,
    pub progress: f64,
    pub is_estimate: bool,
    /// Minutes since prayer ended (only for recently_finished status)
    pub ended_minutes_ago: Option<i64>,
    /// Whether it's still possible to catch the prayer (within catch-up window)
    pub can_still_catch: bool,
}

impl RakahEstimate {
    pub fn not_available(total_rakah: i32) -> Self {
        Self {
            status: "not_available".to_string(),
            current_rakah: None,
            total_rakah,
            elapsed_secs: None,
            remaining_secs: None,
            progress: 0.0,
            is_estimate: false,
            ended_minutes_ago: None,
            can_still_catch: false,
        }
    }
}

/// Travel prediction result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelPrediction {
    pub recommended_leave_time: DateTime<Utc>,
    pub arrival_time: DateTime<Utc>,
    pub arrival_rakah: Option<i32>,
    pub arrival_status: String,
    pub should_leave_now: bool,
    pub time_until_leave_secs: Option<i64>,
    pub is_late: bool,
}

/// Prayer countdown info
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrayerCountdown {
    pub prayer_name: String,
    pub adhan_time: DateTime<Utc>,
    pub iqama_time: Option<DateTime<Utc>>,
    pub time_until_adhan_secs: i64,
    pub time_until_iqama_secs: Option<i64>,
    pub is_active: bool,
}
