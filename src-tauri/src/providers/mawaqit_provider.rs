use async_trait::async_trait;
use chrono::{Datelike, Local, NaiveDate, TimeZone, Utc};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Mutex;
use lazy_static::lazy_static;

use crate::models::*;
use crate::providers::{PrayerDataProvider, ProviderError, ProviderResult};

const MAWAQIT_BASE_URL: &str = "https://mawaqit.net";

// In-memory cache for mosque data
lazy_static! {
    static ref MOSQUE_CACHE: Mutex<HashMap<String, CachedMosqueData>> = Mutex::new(HashMap::new());
}

#[derive(Clone)]
struct CachedMosqueData {
    conf_data: MawaqitConfData,
    cached_at: chrono::DateTime<Utc>,
}

pub struct MawaqitProvider {
    client: Client,
    default_country: String,
}

impl MawaqitProvider {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                .build()
                .unwrap(),
            default_country: "FR".to_string(),
        }
    }

    async fn fetch_country_mosques(&self, country: &str) -> ProviderResult<Vec<MawaqitMosque>> {
        let url = format!("{}/api/2.0/mosque/map/{}", MAWAQIT_BASE_URL, country);

        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to fetch mosques: {}", e)))?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: format!("HTTP error: {}", response.status()),
            });
        }

        let mosques: Vec<MawaqitMosque> = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse response: {}", e))
        })?;

        Ok(mosques)
    }

    async fn scrape_mosque_page(&self, slug: &str) -> ProviderResult<MawaqitConfData> {
        // Check cache first
        {
            let cache = MOSQUE_CACHE.lock().unwrap();
            if let Some(cached) = cache.get(slug) {
                // Cache valid for 1 hour
                if Utc::now().signed_duration_since(cached.cached_at).num_hours() < 1 {
                    log::info!("Using cached mosque data for: {}", slug);
                    return Ok(cached.conf_data.clone());
                }
            }
        }

        let url = format!("{}/en/{}", MAWAQIT_BASE_URL, slug);
        log::info!("Scraping mosque page: {}", url);

        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to fetch mosque page: {}", e)))?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: format!("HTTP error: {}", response.status()),
            });
        }

        let html = response.text().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to read response: {}", e))
        })?;

        log::info!("Got page content, length: {} bytes", html.len());

        let conf_data = extract_conf_data(&html)
            .ok_or_else(|| ProviderError::Parse("Could not find prayer times data (confData) in page".to_string()))?;

        log::info!("Successfully extracted confData");
        log::info!("Mosque Name: {}", conf_data.name);
        log::info!("Times (today): {:?}", conf_data.times);
        log::info!("Calendar has {} months of data", conf_data.calendar.len());
        log::info!("Iqama calendar has {} months of data", conf_data.iqama_calendar.len());
        log::info!("Timezone: {}", conf_data.timezone);

        // Cache the data
        {
            let mut cache = MOSQUE_CACHE.lock().unwrap();
            cache.insert(slug.to_string(), CachedMosqueData {
                conf_data: conf_data.clone(),
                cached_at: Utc::now(),
            });
        }

        Ok(conf_data)
    }

    /// Get prayer times for a specific date from the calendar
    fn get_prayer_times_for_date(
        &self,
        conf_data: &MawaqitConfData,
        date: NaiveDate,
    ) -> Option<(Vec<String>, Vec<String>)> {
        let day = date.day() as usize;
        let month = date.month() as usize;

        log::info!("Looking for prayer times for month {} day {}", month, day);

        // Get prayer times from calendar
        // Calendar is a Vec of months, each month is a HashMap of day -> [Fajr, Shuruq, Dhuhr, Asr, Maghrib, Isha]
        let prayer_times = conf_data.calendar.get(month - 1)
            .and_then(|month_data| month_data.get(&day.to_string()))
            .cloned();

        // Get iqama offsets from iqamaCalendar
        let iqama_offsets = conf_data.iqama_calendar.get(month - 1)
            .and_then(|month_data| month_data.get(&day.to_string()))
            .cloned();

        match (prayer_times, iqama_offsets) {
            (Some(times), Some(offsets)) => {
                log::info!("Found prayer times for month {} day {}: {:?}", month, day, times);
                Some((times, offsets))
            }
            (Some(times), None) => {
                log::info!("Found prayer times but no iqama offsets for month {} day {}", month, day);
                // Return default iqama offsets
                Some((times, vec!["+30".to_string(), "+15".to_string(), "+15".to_string(), "+10".to_string(), "+15".to_string()]))
            }
            _ => {
                log::warn!("No prayer times found for month {} day {}", month, day);
                None
            }
        }
    }

    /// Get today's prayer times from the "times" property
    fn get_today_times_from_conf(&self, conf_data: &MawaqitConfData) -> Option<(Vec<String>, Vec<String>)> {
        if conf_data.times.len() < 5 {
            log::warn!("'times' array has insufficient data: {:?}", conf_data.times);
            return None;
        }

        // Get today's iqama offsets
        let today = Local::now().date_naive();
        let day = today.day() as usize;
        let month = today.month() as usize;

        let iqama_offsets = conf_data.iqama_calendar.get(month - 1)
            .and_then(|month_data| month_data.get(&day.to_string()))
            .cloned()
            .unwrap_or_else(|| vec!["+30".to_string(), "+15".to_string(), "+15".to_string(), "+10".to_string(), "+15".to_string()]);

        // times format: [Fajr, Dhuhr, Asr, Maghrib, Isha] (5 elements)
        // Need to expand to 6 elements for consistency with calendar format
        let mut expanded_times = conf_data.times.clone();
        if expanded_times.len() == 5 {
            // Insert Shuruq (sunrise) placeholder - will use fajr time + offset or from shuruq field
            let shuruq_time = conf_data.shuruq.clone().unwrap_or_else(|| {
                // Estimate shuruq as ~1 hour after fajr
                let fajr_parts: Vec<&str> = expanded_times[0].split(':').collect();
                if fajr_parts.len() == 2 {
                    let hour: i32 = fajr_parts[0].parse().unwrap_or(5);
                    let minute: i32 = fajr_parts[1].parse().unwrap_or(0);
                    let total = hour * 60 + minute + 60; // +60 minutes
                    format!("{:02}:{:02}", total / 60, total % 60)
                } else {
                    "06:00".to_string()
                }
            });
            expanded_times.insert(1, shuruq_time);
        }

        log::info!("Using 'times' property for today: {:?}", expanded_times);
        Some((expanded_times, iqama_offsets))
    }

    fn convert_mosque(&self, m: &MawaqitMosque) -> Mosque {
        Mosque {
            id: m.slug.clone(),
            name: m.name.clone(),
            address: Some(m.address.clone()),
            city: Some(m.city.clone()),
            country: Some(m.country_full_name.clone()),
            latitude: Some(m.lat),
            longitude: Some(m.lng),
            is_favorite: false,
            last_accessed: None,
        }
    }

    fn calculate_iqama(&self, adhan_time: &str, offset_str: &str) -> Option<String> {
        let offset_minutes: i32 = offset_str.trim_start_matches('+').parse().ok()?;

        let parts: Vec<&str> = adhan_time.split(':').collect();
        let adhan_hour: i32 = parts.get(0)?.parse().ok()?;
        let adhan_minute: i32 = parts.get(1)?.parse().ok()?;

        let total_minutes = adhan_hour * 60 + adhan_minute + offset_minutes;
        let iqama_hour = (total_minutes / 60) % 24;
        let iqama_minute = total_minutes % 60;

        Some(format!("{:02}:{:02}", iqama_hour, iqama_minute))
    }
}

#[async_trait]
impl PrayerDataProvider for MawaqitProvider {
    fn id(&self) -> &str {
        "mawaqit"
    }

    fn name(&self) -> &str {
        "Mawaqit"
    }

    fn description(&self) -> &str {
        "Official Mawaqit.net integration with full calendar support"
    }

    fn config_schema(&self) -> Vec<ConfigField> {
        vec![ConfigField::new(
            "default_country",
            "Default Country",
            ConfigFieldType::Select,
        )
        .description("Default country to search in")
        .default_value("FR")
        .options(vec![
            "FR".to_string(),
            "TN".to_string(),
            "MA".to_string(),
            "DZ".to_string(),
            "US".to_string(),
            "GB".to_string(),
            "CA".to_string(),
        ])]
    }

    async fn initialize(&mut self, config: Value) -> ProviderResult<()> {
        if let Some(country) = config["default_country"].as_str() {
            self.default_country = country.to_string();
        }
        Ok(())
    }

    async fn search_mosques(
        &self,
        query: &str,
        _location: Option<&GeoLocation>,
    ) -> ProviderResult<Vec<Mosque>> {
        let mosques = self.fetch_country_mosques(&self.default_country).await?;

        let query_lower = query.to_lowercase();
        let filtered: Vec<Mosque> = mosques
            .into_iter()
            .filter(|m| {
                m.name.to_lowercase().contains(&query_lower)
                    || m.city.to_lowercase().contains(&query_lower)
                    || m.address.to_lowercase().contains(&query_lower)
            })
            .map(|m| self.convert_mosque(&m))
            .collect();

        Ok(filtered)
    }

    async fn get_nearby_mosques(
        &self,
        _location: &GeoLocation,
        _radius_km: f64,
    ) -> ProviderResult<Vec<Mosque>> {
        Err(ProviderError::Other(
            "Nearby search not yet implemented for Mawaqit".to_string(),
        ))
    }

    async fn get_prayer_times(
        &self,
        mosque_id: &str,
        date: Option<NaiveDate>,
    ) -> ProviderResult<PrayerTimes> {
        let conf_data = self.scrape_mosque_page(mosque_id).await?;

        // Use provided date or today
        let target_date = date.unwrap_or_else(|| Local::now().date_naive());
        let today = Local::now().date_naive();
        
        // Use "times" property for today, "calendar" for other dates
        let (prayer_times, iqama_offsets) = if target_date == today {
            log::info!("Using 'times' property for today's prayer times");
            self.get_today_times_from_conf(&conf_data)
                .or_else(|| self.get_prayer_times_for_date(&conf_data, target_date))
                .ok_or_else(|| ProviderError::Parse(
                    "No prayer times found for today".to_string()
                ))?
        } else {
            log::info!("Using 'calendar' property for date: {}", target_date);
            self.get_prayer_times_for_date(&conf_data, target_date)
                .ok_or_else(|| ProviderError::Parse(
                    format!("No prayer times found for date: {}. Calendar has {} months of data.", 
                        target_date, conf_data.calendar.len())
                ))?
        };

        // prayer_times format: [Fajr, Shuruq, Dhuhr, Asr, Maghrib, Isha]
        if prayer_times.len() < 6 {
            return Err(ProviderError::Parse(format!(
                "Invalid prayer times data: expected 6 times (Fajr, Shuruq, Dhuhr, Asr, Maghrib, Isha), got {}. Times: {:?}",
                prayer_times.len(), prayer_times
            )));
        }

        log::info!("Prayer times for {}: Fajr={}, Shuruq={}, Dhuhr={}, Asr={}, Maghrib={}, Isha={}",
            target_date,
            prayer_times[0], prayer_times[1], prayer_times[2], 
            prayer_times[3], prayer_times[4], prayer_times[5]);
        log::info!("Iqama offsets: {:?}", iqama_offsets);

        // Extract individual prayer times
        let fajr_time = &prayer_times[0];
        let _shuruq_time = &prayer_times[1];
        let dhuhr_time = &prayer_times[2];
        let asr_time = &prayer_times[3];
        let maghrib_time = &prayer_times[4];
        let isha_time = &prayer_times[5];

        // Calculate iqama times
        let fajr_iqama = if conf_data.iqama_enabled.unwrap_or(true) && iqama_offsets.len() > 0 {
            self.calculate_iqama(fajr_time, &iqama_offsets[0])
        } else { None };
        
        let dhuhr_iqama = if conf_data.iqama_enabled.unwrap_or(true) && iqama_offsets.len() > 1 {
            self.calculate_iqama(dhuhr_time, &iqama_offsets[1])
        } else { None };
        
        let asr_iqama = if conf_data.iqama_enabled.unwrap_or(true) && iqama_offsets.len() > 2 {
            self.calculate_iqama(asr_time, &iqama_offsets[2])
        } else { None };
        
        let maghrib_iqama = if conf_data.iqama_enabled.unwrap_or(true) && iqama_offsets.len() > 3 {
            self.calculate_iqama(maghrib_time, &iqama_offsets[3])
        } else { None };
        
        let isha_iqama = if conf_data.iqama_enabled.unwrap_or(true) && iqama_offsets.len() > 4 {
            self.calculate_iqama(isha_time, &iqama_offsets[4])
        } else { None };

        log::info!("Calculated iqama times - Fajr: {:?}, Dhuhr: {:?}, Asr: {:?}, Maghrib: {:?}, Isha: {:?}",
            fajr_iqama, dhuhr_iqama, asr_iqama, maghrib_iqama, isha_iqama);

        // Create prayers - use local timezone to avoid 1-hour offset
        let base_date = Local::now().date_naive();
        let base_local = base_date.and_hms_opt(0, 0, 0).unwrap();
        
        let fajr = Prayer {
            name: "Fajr".to_string(),
            adhan: parse_time_local(&base_local, fajr_time),
            iqama: fajr_iqama.map(|t| parse_time_local(&base_local, &t)),
            custom_rakah_count: Some(2),
        };

        let dhuhr = Prayer {
            name: "Dhuhr".to_string(),
            adhan: parse_time_local(&base_local, dhuhr_time),
            iqama: dhuhr_iqama.map(|t| parse_time_local(&base_local, &t)),
            custom_rakah_count: Some(4),
        };

        let asr = Prayer {
            name: "Asr".to_string(),
            adhan: parse_time_local(&base_local, asr_time),
            iqama: asr_iqama.map(|t| parse_time_local(&base_local, &t)),
            custom_rakah_count: Some(4),
        };

        let maghrib = Prayer {
            name: "Maghrib".to_string(),
            adhan: parse_time_local(&base_local, maghrib_time),
            iqama: maghrib_iqama.map(|t| parse_time_local(&base_local, &t)),
            custom_rakah_count: Some(3),
        };

        let isha = Prayer {
            name: "Isha".to_string(),
            adhan: parse_time_local(&base_local, isha_time),
            iqama: isha_iqama.map(|t| parse_time_local(&base_local, &t)),
            custom_rakah_count: Some(4),
        };

        // Jumuah prayer - check if target date is Friday
        let jumuah = if target_date.weekday().num_days_from_monday() == 4 { // Friday = 4
            conf_data.jumua.as_ref().map(|time| Prayer {
                name: "Jumuah".to_string(),
                adhan: parse_time_local(&base_local, time),
                iqama: None,
                custom_rakah_count: Some(2),
            })
        } else {
            None
        };

        let prayer_times = PrayerTimes {
            date: base_local.and_local_timezone(Utc).unwrap(),
            fajr,
            dhuhr,
            asr,
            maghrib,
            isha,
            jumuah,
            mosque_id: Some(mosque_id.to_string()),
            mosque_name: Some(conf_data.name.clone()),
            cached_at: Some(Utc::now()),
        };

        log::info!("Successfully created PrayerTimes for {} on {}", conf_data.name, target_date);

        Ok(prayer_times)
    }

    async fn test_connection(&self) -> ProviderResult<ProviderTestResult> {
        let start = std::time::Instant::now();

        match self.fetch_country_mosques(&self.default_country).await {
            Ok(mosques) => {
                let latency = start.elapsed().as_millis() as u64;
                Ok(ProviderTestResult {
                    success: true,
                    message: format!(
                        "Connected! Found {} mosques in {}",
                        mosques.len(), self.default_country
                    ),
                    latency_ms: Some(latency),
                })
            }
            Err(e) => Ok(ProviderTestResult {
                success: false,
                message: format!("Connection failed: {}", e),
                latency_ms: None,
            }),
        }
    }

    async fn get_mosque_details(&self, mosque_id: &str) -> ProviderResult<Mosque> {
        let conf_data = self.scrape_mosque_page(mosque_id).await?;

        Ok(Mosque {
            id: mosque_id.to_string(),
            name: conf_data.name,
            address: Some(conf_data.url),
            city: Some(conf_data.label),
            country: Some(conf_data.country_code),
            latitude: Some(conf_data.latitude),
            longitude: Some(conf_data.longitude),
            is_favorite: false,
            last_accessed: None,
        })
    }
}

/// Parse time string and create a DateTime in local timezone
/// This ensures the time is stored as-is without timezone conversion issues
fn parse_time_local(base: &chrono::NaiveDateTime, time_str: &str) -> chrono::DateTime<Utc> {
    let parts: Vec<&str> = time_str.split(':').collect();
    let hour: u32 = parts.get(0).and_then(|s| s.parse().ok()).unwrap_or(0);
    let minute: u32 = parts.get(1).and_then(|s| s.parse().ok()).unwrap_or(0);

    // Create the datetime in local timezone, then convert to UTC
    // This preserves the exact hour:minute as shown in Mawaqit
    let local_dt = base.date()
        .and_hms_opt(hour, minute, 0)
        .unwrap();
    
    // Convert to UTC - this preserves the wall-clock time
    Local.from_local_datetime(&local_dt)
        .unwrap()
        .with_timezone(&Utc)
}

fn extract_conf_data(html: &str) -> Option<MawaqitConfData> {
    let pattern = r"let\s+confData\s*=\s*(\{[\s\S]+?\});";
    let regex = regex::Regex::new(pattern).ok()?;

    let captures = regex.captures(html)?;
    let json_str = captures.get(1)?.as_str();

    log::debug!("Extracted confData JSON, length: {} bytes", json_str.len());

    match serde_json::from_str(json_str) {
        Ok(data) => {
            log::debug!("Successfully parsed confData");
            Some(data)
        }
        Err(e) => {
            log::error!("Failed to parse confData JSON: {}", e);
            None
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct MawaqitMosque {
    slug: String,
    name: String,
    #[serde(rename = "image1")]
    image: String,
    address: String,
    city: String,
    #[serde(rename = "zipcode")]
    zip_code: String,
    #[serde(rename = "countryFullName")]
    country_full_name: String,
    lng: f64,
    lat: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct MawaqitConfData {
    name: String,
    label: String,
    #[serde(rename = "countryCode")]
    country_code: String,
    latitude: f64,
    longitude: f64,
    url: String,
    times: Vec<String>, // Today's times: [Fajr, Dhuhr, Asr, Maghrib, Isha]
    shuruq: Option<String>,
    jumua: Option<String>,
    #[serde(rename = "iqamaCalendar")]
    iqama_calendar: Vec<HashMap<String, Vec<String>>>,
    #[serde(rename = "calendar")]
    calendar: Vec<HashMap<String, Vec<String>>>, // Full year calendar
    #[serde(rename = "iqamaEnabled")]
    iqama_enabled: Option<bool>,
    #[serde(rename = "timeDisplayFormat")]
    time_display_format: String,
    timezone: String,
}
