use chrono::{DateTime, Duration, Timelike, Utc};

use crate::models::*;

/// Core prayer calculation engine - Pure, stateless, testable
pub struct PrayerEngine {
    config: PrayerEngineConfig,
}

impl PrayerEngine {
    pub fn new(config: PrayerEngineConfig) -> Self {
        Self { config }
    }

    pub fn with_defaults() -> Self {
        Self {
            config: PrayerEngineConfig::default(),
        }
    }

    /// Get the next prayer from the schedule
    pub fn get_next_prayer(&self, schedule: &PrayerTimes, now: DateTime<Utc>) -> NextPrayerResult {
        let prayers = schedule.all_prayers();

        // Find the next prayer
        for prayer in prayers {
            if prayer.adhan > now {
                return NextPrayerResult {
                    prayer: prayer.clone(),
                    time_until_adhan_secs: (prayer.adhan - now).num_seconds(),
                    time_until_iqama_secs: prayer.iqama.map(|iq| (iq - now).num_seconds()),
                    is_tomorrow: false,
                };
            }

            // If we're between adhan and iqama
            if let Some(iqama) = prayer.iqama {
                if now > prayer.adhan && now < iqama {
                    return NextPrayerResult {
                        prayer: prayer.clone(),
                        time_until_adhan_secs: 0,
                        time_until_iqama_secs: Some((iqama - now).num_seconds()),
                        is_tomorrow: false,
                    };
                }
            }
        }

        // All prayers done for today, return tomorrow's Fajr
        let tomorrow = now + Duration::days(1);
        let tomorrow_fajr = tomorrow
            .date_naive()
            .and_hms_opt(
                schedule.fajr.adhan.hour() as u32,
                schedule.fajr.adhan.minute() as u32,
                0,
            )
            .unwrap()
            .and_local_timezone(Utc)
            .unwrap();

        let tomorrow_fajr_iqama = schedule.fajr.iqama.map(|iq| {
            tomorrow
                .date_naive()
                .and_hms_opt(iq.hour() as u32, iq.minute() as u32, 0)
                .unwrap()
                .and_local_timezone(Utc)
                .unwrap()
        });

        NextPrayerResult {
            prayer: Prayer {
                name: schedule.fajr.name.clone(),
                adhan: tomorrow_fajr,
                iqama: tomorrow_fajr_iqama,
                custom_rakah_count: schedule.fajr.custom_rakah_count,
            },
            time_until_adhan_secs: (tomorrow_fajr - now).num_seconds(),
            time_until_iqama_secs: tomorrow_fajr_iqama.map(|iq| (iq - now).num_seconds()),
            is_tomorrow: true,
        }
    }

    /// Estimate current rakah during prayer
    /// Includes post-prayer window (28 minutes) to show "ended X min ago" message
    pub fn estimate_rakah(&self, prayer: &Prayer, now: DateTime<Utc>) -> RakahEstimate {
        if !prayer.has_iqama() {
            return RakahEstimate::not_available(
                prayer.get_rakah_count(&self.config.default_rakah_counts),
            );
        }

        let iqama = prayer.iqama.unwrap();
        let prayer_start = iqama + Duration::seconds(self.config.start_lag_seconds);
        let total_rakah = prayer.get_rakah_count(&self.config.default_rakah_counts);
        let estimated_duration = Duration::seconds(total_rakah as i64 * self.config.rakah_duration_seconds);
        let prayer_end = prayer_start + estimated_duration;
        let grace_end = prayer_end + Duration::seconds(self.config.grace_seconds);
        let post_prayer_window = prayer_end + Duration::minutes(self.config.post_prayer_display_minutes);

        // Not started yet
        if now < prayer_start {
            return RakahEstimate {
                status: "not_started".to_string(),
                current_rakah: None,
                total_rakah,
                elapsed_secs: None,
                remaining_secs: Some((prayer_start - now).num_seconds()),
                progress: 0.0,
                is_estimate: true,
                ended_minutes_ago: None,
                can_still_catch: false,
            };
        }

        // Prayer ended, but within post-prayer display window (28 min)
        // Show "ended X minutes ago" with optional "you may still catch it"
        if now > prayer_end && now <= post_prayer_window {
            let ended_minutes_ago = ((now - prayer_end).num_seconds() as f64 / 60.0).ceil() as i64;
            let catch_up_window = prayer_end + Duration::minutes(self.config.catch_up_minutes);
            let can_still_catch = now <= catch_up_window;

            return RakahEstimate {
                status: "recently_finished".to_string(),
                current_rakah: Some(total_rakah),
                total_rakah,
                elapsed_secs: Some((now - prayer_start).num_seconds()),
                remaining_secs: None,
                progress: 1.0,
                is_estimate: true,
                ended_minutes_ago: Some(ended_minutes_ago),
                can_still_catch,
            };
        }

        // Beyond post-prayer window - don't show live status at all
        if now > post_prayer_window {
            return RakahEstimate {
                status: "likely_finished".to_string(),
                current_rakah: Some(total_rakah),
                total_rakah,
                elapsed_secs: Some((now - prayer_start).num_seconds()),
                remaining_secs: None,
                progress: 1.0,
                is_estimate: true,
                ended_minutes_ago: None,
                can_still_catch: false,
            };
        }

        // Grace period - prayer might be finishing
        if now > prayer_end && now <= prayer_end + Duration::seconds(self.config.grace_seconds) {
            return RakahEstimate {
                status: "in_progress".to_string(),
                current_rakah: Some(total_rakah),
                total_rakah,
                elapsed_secs: Some((now - prayer_start).num_seconds()),
                remaining_secs: Some(0),
                progress: 1.0,
                is_estimate: true,
                ended_minutes_ago: None,
                can_still_catch: false,
            };
        }

        // In progress - calculate rakah
        let elapsed = now - prayer_start;
        let raw_rakah_index = (elapsed.num_seconds() / self.config.rakah_duration_seconds) + 1;
        let current_rakah = raw_rakah_index.clamp(1, total_rakah as i64) as i32;
        let progress = elapsed.num_seconds() as f64 / estimated_duration.num_seconds() as f64;

        RakahEstimate {
            status: "in_progress".to_string(),
            current_rakah: Some(current_rakah),
            total_rakah,
            elapsed_secs: Some(elapsed.num_seconds()),
            remaining_secs: if prayer_end > now {
                Some((prayer_end - now).num_seconds())
            } else {
                None
            },
            progress: progress.clamp(0.0, 1.0),
            is_estimate: true,
            ended_minutes_ago: None,
            can_still_catch: false,
        }
    }

    /// Calculate travel prediction
    pub fn calculate_travel_prediction(
        &self,
        prayer: &Prayer,
        travel_time_secs: i64,
        now: DateTime<Utc>,
    ) -> TravelPrediction {
        if !prayer.has_iqama() {
            return TravelPrediction {
                recommended_leave_time: now,
                arrival_time: now + Duration::seconds(travel_time_secs),
                arrival_rakah: None,
                arrival_status: "iqama_unavailable".to_string(),
                should_leave_now: false,
                time_until_leave_secs: None,
                is_late: false,
            };
        }

        let iqama = prayer.iqama.unwrap();
        let prayer_start = iqama + Duration::seconds(self.config.start_lag_seconds);
        let desired_arrival = prayer_start - Duration::seconds(self.config.buffer_before_start_seconds);
        let recommended_leave = desired_arrival - Duration::seconds(travel_time_secs);
        let arrival_time = now + Duration::seconds(travel_time_secs);

        let total_rakah = prayer.get_rakah_count(&self.config.default_rakah_counts);

        // Should leave now?
        let should_leave_now = now >= recommended_leave;
        let is_late = now > prayer_start;

        // Calculate arrival rakah
        let (arrival_rakah, arrival_status) = if arrival_time < prayer_start {
            (Some(0), "before_start".to_string())
        } else {
            let arrival_elapsed = arrival_time - prayer_start;
            let raw_rakah = (arrival_elapsed.num_seconds() / self.config.rakah_duration_seconds) + 1;
            let arrival_rakah = raw_rakah.clamp(1, total_rakah as i64) as i32;

            if arrival_rakah > total_rakah {
                (None, "after_estimated_end".to_string())
            } else {
                (Some(arrival_rakah), "in_progress".to_string())
            }
        };

        TravelPrediction {
            recommended_leave_time: recommended_leave,
            arrival_time,
            arrival_rakah,
            arrival_status,
            should_leave_now,
            time_until_leave_secs: if now < recommended_leave {
                Some((recommended_leave - now).num_seconds())
            } else {
                None
            },
            is_late,
        }
    }

    /// Get countdown until iqama
    pub fn get_countdown(&self, prayer: &Prayer, now: DateTime<Utc>) -> Option<i64> {
        prayer.iqama.map(|iq| {
            if now > iq {
                0
            } else {
                (iq - now).num_seconds()
            }
        })
    }

    /// Format duration for display
    pub fn format_duration(&self, seconds: i64) -> String {
        let hours = seconds / 3600;
        let minutes = (seconds % 3600) / 60;
        let secs = seconds % 60;

        if hours > 0 {
            format!("{}h {}m", hours, minutes)
        } else if minutes > 0 {
            format!("{}m {}s", minutes, secs)
        } else {
            format!("{}s", secs)
        }
    }

    /// Get current or next prayer for a given time
    pub fn get_current_prayer<'a>(&self, schedule: &'a PrayerTimes, now: DateTime<Utc>) -> Option<&'a Prayer> {
        let prayers = schedule.all_prayers();

        for i in 0..prayers.len() {
            let prayer = prayers[i];
            let next_prayer = prayers.get(i + 1);

            // Check if we're in this prayer's time window
            if now > prayer.adhan {
                if let Some(next) = next_prayer {
                    if now < next.adhan {
                        return Some(prayer);
                    }
                } else {
                    return Some(prayer);
                }
            }
        }

        None
    }

    /// Get all prayer countdowns
    pub fn get_all_countdowns(&self, schedule: &PrayerTimes, now: DateTime<Utc>) -> Vec<PrayerCountdown> {
        schedule
            .all_prayers()
            .into_iter()
            .map(|prayer| {
                let time_until_adhan = (prayer.adhan - now).num_seconds();
                let time_until_iqama = prayer.iqama.map(|iq| {
                    if now > iq {
                        0
                    } else {
                        (iq - now).num_seconds()
                    }
                });

                PrayerCountdown {
                    prayer_name: prayer.name.clone(),
                    adhan_time: prayer.adhan,
                    iqama_time: prayer.iqama,
                    time_until_adhan_secs: time_until_adhan.max(0),
                    time_until_iqama_secs: time_until_iqama,
                    is_active: time_until_adhan <= 0 && time_until_iqama.map(|t| t > 0).unwrap_or(false),
                }
            })
            .collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_schedule() -> PrayerTimes {
        let now = Utc::now();
        let date = now.date_naive().and_hms_opt(0, 0, 0).unwrap().and_local_timezone(Utc).unwrap();

        PrayerTimes {
            date,
            mosque_id: Some("test-mosque".to_string()),
            mosque_name: Some("Test Mosque".to_string()),
            fajr: Prayer {
                name: "Fajr".to_string(),
                adhan: date + Duration::hours(5),
                iqama: Some(date + Duration::hours(5) + Duration::minutes(15)),
                custom_rakah_count: None,
            },
            dhuhr: Prayer {
                name: "Dhuhr".to_string(),
                adhan: date + Duration::hours(12),
                iqama: Some(date + Duration::hours(12) + Duration::minutes(15)),
                custom_rakah_count: None,
            },
            asr: Prayer {
                name: "Asr".to_string(),
                adhan: date + Duration::hours(15),
                iqama: Some(date + Duration::hours(15) + Duration::minutes(15)),
                custom_rakah_count: None,
            },
            maghrib: Prayer {
                name: "Maghrib".to_string(),
                adhan: date + Duration::hours(18),
                iqama: Some(date + Duration::hours(18) + Duration::minutes(5)),
                custom_rakah_count: None,
            },
            isha: Prayer {
                name: "Isha".to_string(),
                adhan: date + Duration::hours(19) + Duration::minutes(30),
                iqama: Some(date + Duration::hours(19) + Duration::minutes(45)),
                custom_rakah_count: None,
            },
            jumuah: None,
            cached_at: Some(now),
        }
    }

    #[test]
    fn test_get_next_prayer() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let now = schedule.date + Duration::hours(10); // Before Dhuhr

        let result = engine.get_next_prayer(&schedule, now);

        assert_eq!(result.prayer.name, "Dhuhr");
        assert!(!result.is_tomorrow);
    }

    #[test]
    fn test_estimate_rakah() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr;

        // 2 minutes after iqama (in first or second rakah - 2 min / 2.4 min per rakah)
        let now = prayer.iqama.unwrap() + Duration::minutes(2);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "in_progress");
        // 2 min = 120 sec / 144 sec per rakah = 0.83 -> floor(0.83) + 1 = 1st rakah
        assert!(estimate.current_rakah.unwrap() >= 1);
        assert!(estimate.current_rakah.unwrap() <= 2);
    }

    // ============================================================================
    // LIVE STATUS TESTS
    // ============================================================================

    #[test]
    fn test_live_status_before_iqama() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr;

        // 10 minutes before iqama
        let now = prayer.iqama.unwrap() - Duration::minutes(10);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "not_started");
        assert!(estimate.remaining_secs.is_some());
        assert_eq!(estimate.remaining_secs.unwrap(), 600); // 10 minutes in seconds
        assert_eq!(estimate.progress, 0.0);
    }

    #[test]
    fn test_live_status_at_iqama_start() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr;

        // Exactly at iqama time
        let now = prayer.iqama.unwrap();
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "in_progress");
        assert_eq!(estimate.current_rakah, Some(1));
        assert_eq!(estimate.elapsed_secs, Some(0));
        assert_eq!(estimate.progress, 0.0);
    }

    #[test]
    fn test_live_status_during_first_rakah() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr;

        // 2 minutes after iqama (within first 2.4 min = first rakah)
        let now = prayer.iqama.unwrap() + Duration::minutes(2);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "in_progress");
        assert_eq!(estimate.current_rakah, Some(1));
        assert!(estimate.elapsed_secs.unwrap() >= 120);
        assert!(estimate.progress > 0.0 && estimate.progress < 0.25); // Less than 1/4 of 4 rakahs
    }

    #[test]
    fn test_live_status_during_third_rakah() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr; // 4 rakahs

        // 6 minutes after iqama (within third rakah)
        // 6 min / 2.4 min per rakah = 2.5 -> 3rd rakah
        let now = prayer.iqama.unwrap() + Duration::minutes(6);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "in_progress");
        assert_eq!(estimate.current_rakah, Some(3));
        assert!(estimate.progress > 0.5 && estimate.progress < 0.75);
    }

    #[test]
    fn test_live_status_at_last_rakah() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.maghrib; // 3 rakahs = ~7.2 min

        // 6 minutes after iqama (within last rakah for maghrib)
        // 6 min / 2.4 min per rakah = 2.5 -> 3rd (last) rakah
        let now = prayer.iqama.unwrap() + Duration::minutes(6);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "in_progress");
        assert_eq!(estimate.current_rakah, Some(3));
        assert!(estimate.progress > 0.6);
    }

    #[test]
    fn test_live_status_prayer_finished() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.fajr; // 2 rakahs = ~4.8 minutes

        // 6 minutes after iqama (finished ~1.2 min ago, within post-prayer window)
        // Should show "recently_finished" with can_still_catch = true (within 3 min)
        let now = prayer.iqama.unwrap() + Duration::minutes(6);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "recently_finished");
        assert_eq!(estimate.current_rakah, Some(2)); // Last rakah
        assert_eq!(estimate.progress, 1.0);
        assert!(estimate.elapsed_secs.unwrap() >= 360);
        assert!(estimate.can_still_catch); // Within 3-min catch-up window
        assert_eq!(estimate.ended_minutes_ago, Some(2)); // 6 - 4.8 ≈ 2 min ago
    }

    #[test]
    fn test_live_status_prayer_finished_long_ago() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.fajr; // 2 rakahs = ~4.8 minutes

        // 35 minutes after iqama (well past the 28-min post-prayer window)
        let now = prayer.iqama.unwrap() + Duration::minutes(35);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "likely_finished");
        assert_eq!(estimate.current_rakah, Some(2));
        assert!(!estimate.can_still_catch);
    }

    #[test]
    fn test_live_status_recently_finished_catch_up() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr; // 4 rakahs = ~9.6 minutes

        // 12 minutes after iqama (ended ~2.4 min ago, within catch-up window)
        let now = prayer.iqama.unwrap() + Duration::minutes(12);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "recently_finished");
        assert!(estimate.can_still_catch); // Within 3-min catch-up window
        assert_eq!(estimate.ended_minutes_ago, Some(3)); // 12 - 9.6 ≈ 3 min ago
    }

    #[test]
    fn test_live_status_recently_finished_missed() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr; // 4 rakahs = ~9.6 minutes

        // 15 minutes after iqama (ended ~5.4 min ago, past catch-up window)
        let now = prayer.iqama.unwrap() + Duration::minutes(15);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.status, "recently_finished");
        assert!(!estimate.can_still_catch); // Past 3-min catch-up window
    }

    #[test]
    fn test_live_status_fajr_2_rakahs() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.fajr;

        // Should have 2 rakahs
        assert_eq!(prayer.get_rakah_count(&engine.config.default_rakah_counts), 2);

        // 3 minutes after iqama - should be in 2nd rakah
        let now = prayer.iqama.unwrap() + Duration::minutes(3);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.total_rakah, 2);
        assert_eq!(estimate.current_rakah, Some(2));
    }

    #[test]
    fn test_live_status_maghrib_3_rakahs() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.maghrib;

        // Should have 3 rakahs
        assert_eq!(prayer.get_rakah_count(&engine.config.default_rakah_counts), 3);

        // 5 minutes after iqama - should be in 3rd rakah
        let now = prayer.iqama.unwrap() + Duration::minutes(5);
        let estimate = engine.estimate_rakah(prayer, now);

        assert_eq!(estimate.total_rakah, 3);
        assert_eq!(estimate.current_rakah, Some(3));
    }

    #[test]
    fn test_live_status_no_iqama() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        
        // Create prayer without iqama
        let prayer_without_iqama = Prayer {
            name: "Test".to_string(),
            adhan: Utc::now(),
            iqama: None,
            custom_rakah_count: Some(4),
        };

        let estimate = engine.estimate_rakah(&prayer_without_iqama, Utc::now());

        assert_eq!(estimate.status, "not_available");
        assert!(estimate.current_rakah.is_none());
    }

    #[test]
    fn test_elapsed_time_accuracy() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr;

        let test_cases = vec![
            (Duration::minutes(1), 60),
            (Duration::minutes(5), 300),
            (Duration::minutes(10), 600),
        ];

        for (duration, expected_seconds) in test_cases {
            let now = prayer.iqama.unwrap() + duration;
            let estimate = engine.estimate_rakah(prayer, now);

            assert_eq!(estimate.elapsed_secs, Some(expected_seconds),
                "Elapsed time should be {} seconds", expected_seconds);
        }
    }

    #[test]
    fn test_countdown_updates_correctly() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        
        // Test countdown for next prayer
        let now = schedule.date + Duration::hours(10); // 10 AM
        let result = engine.get_next_prayer(&schedule, now);
        
        assert_eq!(result.prayer.name, "Dhuhr");
        assert_eq!(result.time_until_adhan_secs, 7200); // 2 hours

        // Test with time closer to prayer
        let now = schedule.date + Duration::hours(11) + Duration::minutes(30);
        let result = engine.get_next_prayer(&schedule, now);
        
        assert_eq!(result.prayer.name, "Dhuhr");
        assert_eq!(result.time_until_adhan_secs, 1800); // 30 minutes
    }

    #[test]
    fn test_midnight_crossover_next_prayer() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        
        // After Isha (night time)
        let now = schedule.date + Duration::hours(22);
        let result = engine.get_next_prayer(&schedule, now);
        
        // Should return tomorrow's Fajr
        assert_eq!(result.prayer.name, "Fajr");
        assert!(result.is_tomorrow);
        assert!(result.time_until_adhan_secs > 3600); // More than 1 hour
    }

    #[test]
    fn test_get_all_countdowns() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let now = schedule.date + Duration::hours(10); // 10 AM

        let countdowns = engine.get_all_countdowns(&schedule, now);

        // Should have 5 countdowns (Fajr, Dhuhr, Asr, Maghrib, Isha)
        assert_eq!(countdowns.len(), 5);

        // Fajr should be marked as passed (negative or zero time)
        let fajr_countdown = countdowns.iter().find(|c| c.prayer_name == "Fajr").unwrap();
        assert!(fajr_countdown.time_until_adhan_secs == 0);

        // Dhuhr should have 2 hours remaining
        let dhuhr_countdown = countdowns.iter().find(|c| c.prayer_name == "Dhuhr").unwrap();
        assert_eq!(dhuhr_countdown.time_until_adhan_secs, 7200);
    }

    #[test]
    fn test_active_prayer_detection() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        
        // Between adhan and iqama of Dhuhr (active)
        let now = schedule.dhuhr.adhan + Duration::minutes(5);
        let countdowns = engine.get_all_countdowns(&schedule, now);
        
        let dhuhr_countdown = countdowns.iter().find(|c| c.prayer_name == "Dhuhr").unwrap();
        assert!(dhuhr_countdown.is_active);
        assert_eq!(dhuhr_countdown.time_until_adhan_secs, 0);

        // After iqama (not active anymore)
        let now = schedule.dhuhr.iqama.unwrap() + Duration::minutes(5);
        let countdowns = engine.get_all_countdowns(&schedule, now);
        
        let dhuhr_countdown = countdowns.iter().find(|c| c.prayer_name == "Dhuhr").unwrap();
        assert!(!dhuhr_countdown.is_active);
    }

    #[test]
    fn test_rakah_progress_percentage() {
        let engine = PrayerEngine::with_defaults();
        let schedule = create_test_schedule();
        let prayer = &schedule.dhuhr; // 4 rakahs

        // Test progress at various points
        let test_cases = vec![
            (0, 0.0),                       // Start
            (144, 0.25),                    // After 1st rakah (2.4 min)
            (288, 0.5),                     // After 2nd rakah (4.8 min)
            (432, 0.75),                    // After 3rd rakah (7.2 min)
            (576, 1.0),                     // After 4th rakah (9.6 min)
        ];

        for (seconds, expected_progress) in test_cases {
            let now = prayer.iqama.unwrap() + Duration::seconds(seconds);
            let estimate = engine.estimate_rakah(prayer, now);

            let tolerance = 0.01; // 1% tolerance
            assert!(
                (estimate.progress - expected_progress).abs() < tolerance,
                "Progress should be approximately {} at {} seconds, got {}",
                expected_progress, seconds, estimate.progress
            );
        }
    }
}
