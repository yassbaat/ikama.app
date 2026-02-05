use async_trait::async_trait;
use chrono::{NaiveDate, Utc};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::models::*;
use crate::providers::{PrayerDataProvider, ProviderError, ProviderResult};

/// Community Wrapper API Provider (Provider B)
/// REST API wrapper that provides a simplified interface
pub struct CommunityWrapperProvider {
    client: Client,
    base_url: Option<String>,
    api_key: Option<String>,
}

impl CommunityWrapperProvider {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: None,
            api_key: None,
        }
    }

    fn ensure_initialized(&self) -> ProviderResult<(String, Option<String>)> {
        match &self.base_url {
            Some(url) => Ok((url.clone(), self.api_key.clone())),
            None => Err(ProviderError::InvalidConfig(
                "Provider not initialized".to_string(),
            )),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct MosqueResponse {
    id: String,
    name: String,
    address: Option<String>,
    city: Option<String>,
    country: Option<String>,
    latitude: Option<f64>,
    longitude: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PrayerTimesResponse {
    date: String,
    fajr: PrayerResponse,
    dhuhr: PrayerResponse,
    asr: PrayerResponse,
    maghrib: PrayerResponse,
    isha: PrayerResponse,
    jumuah: Option<PrayerResponse>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PrayerResponse {
    adhan: String,
    iqama: Option<String>,
    rakah_count: Option<i32>,
}

#[async_trait]
impl PrayerDataProvider for CommunityWrapperProvider {
    fn id(&self) -> &str {
        PROVIDER_COMMUNITY_WRAPPER
    }

    fn name(&self) -> &str {
        "Community Wrapper API"
    }

    fn description(&self) -> &str {
        "Community-provided REST API wrapper for prayer times data"
    }

    fn config_schema(&self) -> Vec<ConfigField> {
        vec![
            ConfigField::new("base_url", "API Base URL", ConfigFieldType::Url)
                .required()
                .description("The base URL of the community API"),
            ConfigField::new("api_key", "API Key", ConfigFieldType::Password)
                .description("Optional API key for authentication"),
        ]
    }

    async fn initialize(&mut self, config: Value) -> ProviderResult<()> {
        self.base_url = config["base_url"]
            .as_str()
            .map(|s| s.trim_end_matches('/').to_string());
        self.api_key = config["api_key"].as_str().map(|s| s.to_string());
        Ok(())
    }

    async fn search_mosques(&self, query: &str, _location: Option<&GeoLocation>) -> ProviderResult<Vec<Mosque>> {
        let (base_url, api_key) = self.ensure_initialized()?;

        let mut request = self.client.get(format!("{}/mosques/search", base_url));
        request = request.query(&[("q", query)]);

        if let Some(key) = api_key {
            request = request.header("X-API-Key", key);
        }

        let response = request.send().await.map_err(|e| {
            ProviderError::Network(format!("Failed to search mosques: {}", e))
        })?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to search mosques".to_string(),
            });
        }

        let mosques: Vec<MosqueResponse> = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse response: {}", e))
        })?;

        Ok(mosques
            .into_iter()
            .map(|m| Mosque {
                id: m.id,
                name: m.name,
                address: m.address,
                city: m.city,
                country: m.country,
                latitude: m.latitude,
                longitude: m.longitude,
                is_favorite: false,
                last_accessed: None,
            })
            .collect())
    }

    async fn get_nearby_mosques(&self, location: &GeoLocation, radius_km: f64) -> ProviderResult<Vec<Mosque>> {
        let (base_url, api_key) = self.ensure_initialized()?;

        let mut request = self.client.get(format!("{}/mosques/nearby", base_url));
        request = request.query(&[
            ("lat", location.latitude.to_string()),
            ("lng", location.longitude.to_string()),
            ("radius", radius_km.to_string()),
        ]);

        if let Some(key) = api_key {
            request = request.header("X-API-Key", key);
        }

        let response = request.send().await.map_err(|e| {
            ProviderError::Network(format!("Failed to get nearby mosques: {}", e))
        })?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to get nearby mosques".to_string(),
            });
        }

        let mosques: Vec<MosqueResponse> = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse response: {}", e))
        })?;

        Ok(mosques
            .into_iter()
            .map(|m| Mosque {
                id: m.id,
                name: m.name,
                address: m.address,
                city: m.city,
                country: m.country,
                latitude: m.latitude,
                longitude: m.longitude,
                is_favorite: false,
                last_accessed: None,
            })
            .collect())
    }

    async fn get_prayer_times(&self, mosque_id: &str, date: Option<NaiveDate>) -> ProviderResult<PrayerTimes> {
        let (base_url, api_key) = self.ensure_initialized()?;

        let mut request = self
            .client
            .get(format!("{}/mosques/{}/prayer-times", base_url, mosque_id));

        if let Some(d) = date {
            request = request.query(&[("date", d.format("%Y-%m-%d").to_string())]);
        }

        if let Some(key) = api_key {
            request = request.header("X-API-Key", key);
        }

        let response = request.send().await.map_err(|e| {
            ProviderError::Network(format!("Failed to get prayer times: {}", e))
        })?;

        if response.status().as_u16() == 404 {
            return Err(ProviderError::NotFound(format!(
                "Mosque {} not found",
                mosque_id
            )));
        }

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to get prayer times".to_string(),
            });
        }

        let times: PrayerTimesResponse = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse response: {}", e))
        })?;

        let date = NaiveDate::parse_from_str(&times.date, "%Y-%m-%d")
            .map_err(|e| ProviderError::Parse(format!("Invalid date: {}", e)))?
            .and_hms_opt(0, 0, 0)
            .unwrap()
            .and_local_timezone(Utc)
            .unwrap();

        fn parse_prayer(name: &str, p: PrayerResponse, date: chrono::DateTime<Utc>) -> Prayer {
            let time_part = |t: &str| {
                let parts: Vec<&str> = t.split(':').collect();
                let hour: u32 = parts[0].parse().unwrap_or(0);
                let minute: u32 = parts.get(1).unwrap_or(&"0").parse().unwrap_or(0);
                date.date_naive().and_hms_opt(hour, minute, 0).unwrap().and_local_timezone(Utc).unwrap()
            };

            Prayer {
                name: name.to_string(),
                adhan: time_part(&p.adhan),
                iqama: p.iqama.as_ref().map(|t| time_part(t)),
                custom_rakah_count: p.rakah_count,
            }
        }

        Ok(PrayerTimes {
            date,
            fajr: parse_prayer("Fajr", times.fajr, date),
            dhuhr: parse_prayer("Dhuhr", times.dhuhr, date),
            asr: parse_prayer("Asr", times.asr, date),
            maghrib: parse_prayer("Maghrib", times.maghrib, date),
            isha: parse_prayer("Isha", times.isha, date),
            jumuah: times.jumuah.map(|j| parse_prayer("Jumuah", j, date)),
            mosque_id: Some(mosque_id.to_string()),
            mosque_name: None,
            cached_at: Some(Utc::now()),
        })
    }

    async fn test_connection(&self) -> ProviderResult<ProviderTestResult> {
        let start = std::time::Instant::now();

        let (base_url, api_key) = self.ensure_initialized()?;

        let mut request = self.client.get(format!("{}/health", base_url));

        if let Some(key) = api_key {
            request = request.header("X-API-Key", key);
        }

        match request.send().await {
            Ok(response) => {
                let latency = start.elapsed().as_millis() as u64;
                if response.status().is_success() {
                    Ok(ProviderTestResult {
                        success: true,
                        message: "Connection successful".to_string(),
                        latency_ms: Some(latency),
                    })
                } else {
                    Ok(ProviderTestResult {
                        success: false,
                        message: format!("Server returned: {}", response.status()),
                        latency_ms: Some(latency),
                    })
                }
            }
            Err(e) => Ok(ProviderTestResult {
                success: false,
                message: format!("Connection failed: {}", e),
                latency_ms: None,
            }),
        }
    }

    async fn get_mosque_details(&self, mosque_id: &str) -> ProviderResult<Mosque> {
        let (base_url, api_key) = self.ensure_initialized()?;

        let mut request = self
            .client
            .get(format!("{}/mosques/{}", base_url, mosque_id));

        if let Some(key) = api_key {
            request = request.header("X-API-Key", key);
        }

        let response = request.send().await.map_err(|e| {
            ProviderError::Network(format!("Failed to get mosque details: {}", e))
        })?;

        if response.status().as_u16() == 404 {
            return Err(ProviderError::NotFound(format!(
                "Mosque {} not found",
                mosque_id
            )));
        }

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to get mosque details".to_string(),
            });
        }

        let m: MosqueResponse = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse response: {}", e))
        })?;

        Ok(Mosque {
            id: m.id,
            name: m.name,
            address: m.address,
            city: m.city,
            country: m.country,
            latitude: m.latitude,
            longitude: m.longitude,
            is_favorite: false,
            last_accessed: None,
        })
    }
}
