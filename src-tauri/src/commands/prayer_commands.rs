use chrono::{NaiveDate, Utc};
use tauri::State;

use crate::db::Database;
use crate::models::*;
use crate::services::PrayerEngine;

/// Get next prayer for a mosque
#[tauri::command]
pub async fn get_next_prayer(
    mosque_id: String,
    db: State<'_, Database>,
) -> Result<NextPrayerResult, String> {
    let today = chrono::Local::now().date_naive();

    let prayer_times = db
        .get_prayer_times(&mosque_id, today)
        .await
        .map_err(|e| format!("Database error: {}", e))?
        .ok_or_else(|| "No prayer times found".to_string())?;

    let engine = PrayerEngine::with_defaults();
    let now = Utc::now();

    Ok(engine.get_next_prayer(&prayer_times, now))
}

/// Get all prayer times for a mosque (optionally for a specific date)
/// Date format: "YYYY-MM-DD" (e.g., "2026-02-05")
#[tauri::command]
pub async fn get_prayer_times(
    mosque_id: String,
    date: Option<String>,
    db: State<'_, Database>,
) -> Result<PrayerTimes, String> {
    let target_date = match date {
        Some(d) => NaiveDate::parse_from_str(&d, "%Y-%m-%d")
            .map_err(|e| format!("Invalid date format. Use YYYY-MM-DD: {}", e))?,
        None => chrono::Local::now().date_naive(),
    };

    db.get_prayer_times(&mosque_id, target_date)
        .await
        .map_err(|e| format!("Database error: {}", e))?
        .ok_or_else(|| format!("No prayer times found for {}", target_date))
}

/// Get all prayer countdowns
#[tauri::command]
pub async fn get_all_countdowns(
    mosque_id: String,
    db: State<'_, Database>,
) -> Result<Vec<PrayerCountdown>, String> {
    let today = chrono::Local::now().date_naive();

    let prayer_times = db
        .get_prayer_times(&mosque_id, today)
        .await
        .map_err(|e| format!("Database error: {}", e))?
        .ok_or_else(|| "No prayer times found".to_string())?;

    let engine = PrayerEngine::with_defaults();
    let now = Utc::now();

    Ok(engine.get_all_countdowns(&prayer_times, now))
}

/// Estimate current rakah for a prayer
#[tauri::command]
pub async fn estimate_rakah(
    mosque_id: String,
    prayer_name: String,
    db: State<'_, Database>,
) -> Result<RakahEstimate, String> {
    let today = chrono::Local::now().date_naive();

    let prayer_times = db
        .get_prayer_times(&mosque_id, today)
        .await
        .map_err(|e| format!("Database error: {}", e))?
        .ok_or_else(|| "No prayer times found".to_string())?;

    let prayer = prayer_times
        .get_prayer_by_name(&prayer_name)
        .ok_or_else(|| format!("Prayer {} not found", prayer_name))?;

    let engine = PrayerEngine::with_defaults();
    let now = Utc::now();

    Ok(engine.estimate_rakah(prayer, now))
}

/// Calculate travel prediction
#[tauri::command]
pub async fn calculate_travel_prediction(
    mosque_id: String,
    prayer_name: String,
    travel_time_seconds: i64,
    db: State<'_, Database>,
) -> Result<TravelPrediction, String> {
    let today = chrono::Local::now().date_naive();

    let prayer_times = db
        .get_prayer_times(&mosque_id, today)
        .await
        .map_err(|e| format!("Database error: {}", e))?
        .ok_or_else(|| "No prayer times found".to_string())?;

    let prayer = prayer_times
        .get_prayer_by_name(&prayer_name)
        .ok_or_else(|| format!("Prayer {} not found", prayer_name))?;

    let engine = PrayerEngine::with_defaults();
    let now = Utc::now();

    Ok(engine.calculate_travel_prediction(prayer, travel_time_seconds, now))
}

/// Get countdown to iqama
#[tauri::command]
pub async fn get_countdown(
    mosque_id: String,
    prayer_name: String,
    db: State<'_, Database>,
) -> Result<Option<i64>, String> {
    let today = chrono::Local::now().date_naive();

    let prayer_times = db
        .get_prayer_times(&mosque_id, today)
        .await
        .map_err(|e| format!("Database error: {}", e))?
        .ok_or_else(|| "No prayer times found".to_string())?;

    let prayer = prayer_times
        .get_prayer_by_name(&prayer_name)
        .ok_or_else(|| format!("Prayer {} not found", prayer_name))?;

    let engine = PrayerEngine::with_defaults();
    let now = Utc::now();

    Ok(engine.get_countdown(prayer, now))
}

/// Format duration for display
#[tauri::command]
pub fn format_duration(seconds: i64) -> String {
    let engine = PrayerEngine::with_defaults();
    engine.format_duration(seconds)
}
