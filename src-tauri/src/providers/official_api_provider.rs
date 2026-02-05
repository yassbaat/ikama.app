use async_trait::async_trait;
use chrono::{NaiveDate, Utc};
use reqwest::Client;
use serde_json::Value;

use crate::models::*;
use crate::providers::{PrayerDataProvider, ProviderError, ProviderResult};

/// Official API Provider (Provider A)
/// Direct Mawaqit API access (requires token)
pub struct OfficialApiProvider {
    client: Client,
    base_url: String,
    api_token: Option<String>,
}

impl OfficialApiProvider {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "https://mawaqit.net/api".to_string(),
            api_token: None,
        }
    }

    fn ensure_initialized(&self) -> ProviderResult<&str> {
        self.api_token.as_deref().ok_or_else(|| {
            ProviderError::InvalidConfig("API token required".to_string())
        })
    }
}

#[async_trait]
impl PrayerDataProvider for OfficialApiProvider {
    fn id(&self) -> &str {
        PROVIDER_OFFICIAL_API
    }

    fn name(&self) -> &str {
        "Mawaqit Official API"
    }

    fn description(&self) -> &str {
        "Direct access to Mawaqit prayer times API (requires API token)"
    }

    fn config_schema(&self) -> Vec<ConfigField> {
        vec![
            ConfigField::new("api_token", "API Token", ConfigFieldType::Password)
                .required()
                .description("Your Mawaqit API token"),
            ConfigField::new("base_url", "Base URL", ConfigFieldType::Url)
                .default_value("https://mawaqit.net/api")
                .description("Optional: Custom API base URL"),
        ]
    }

    async fn initialize(&mut self, config: Value) -> ProviderResult<()> {
        if let Some(token) = config["api_token"].as_str() {
            self.api_token = Some(token.to_string());
        }
        if let Some(url) = config["base_url"].as_str() {
            self.base_url = url.trim_end_matches('/').to_string();
        }
        Ok(())
    }

    async fn search_mosques(&self, query: &str, _location: Option<&GeoLocation>) -> ProviderResult<Vec<Mosque>> {
        let token = self.ensure_initialized()?;

        let response = self.client
            .get(format!("{}/mosques/search", self.base_url))
            .query(&[("word", query)])
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to search: {}", e)))?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Search failed".to_string(),
            });
        }

        let data: Vec<serde_json::Value> = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse: {}", e))
        })?;

        let mosques: Vec<Mosque> = data
            .into_iter()
            .filter_map(|v| {
                Some(Mosque {
                    id: v.get("id")?.as_str()?.to_string(),
                    name: v.get("name")?.as_str()?.to_string(),
                    address: v.get("address")?.as_str().map(|s| s.to_string()),
                    city: v.get("city")?.as_str().map(|s| s.to_string()),
                    country: v.get("country")?.as_str().map(|s| s.to_string()),
                    latitude: v.get("latitude")?.as_f64(),
                    longitude: v.get("longitude")?.as_f64(),
                    is_favorite: false,
                    last_accessed: None,
                })
            })
            .collect();

        Ok(mosques)
    }

    async fn get_nearby_mosques(&self, location: &GeoLocation, radius_km: f64) -> ProviderResult<Vec<Mosque>> {
        let token = self.ensure_initialized()?;

        let response = self.client
            .get(format!("{}/mosques/nearby", self.base_url))
            .query(&[
                ("lat", location.latitude.to_string()),
                ("lon", location.longitude.to_string()),
                ("radius", radius_km.to_string()),
            ])
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to get nearby: {}", e)))?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Nearby search failed".to_string(),
            });
        }

        let data: Vec<serde_json::Value> = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse: {}", e))
        })?;

        let mosques: Vec<Mosque> = data
            .into_iter()
            .filter_map(|v| {
                Some(Mosque {
                    id: v.get("id")?.as_str()?.to_string(),
                    name: v.get("name")?.as_str()?.to_string(),
                    address: v.get("address")?.as_str().map(|s| s.to_string()),
                    city: v.get("city")?.as_str().map(|s| s.to_string()),
                    country: v.get("country")?.as_str().map(|s| s.to_string()),
                    latitude: v.get("latitude")?.as_f64(),
                    longitude: v.get("longitude")?.as_f64(),
                    is_favorite: false,
                    last_accessed: None,
                })
            })
            .collect();

        Ok(mosques)
    }

    async fn get_prayer_times(&self, mosque_id: &str, date: Option<NaiveDate>) -> ProviderResult<PrayerTimes> {
        let token = self.ensure_initialized()?;

        let mut request = self.client
            .get(format!("{}/mosques/{}/times", self.base_url, mosque_id));

        if let Some(d) = date {
            request = request.query(&[("date", d.format("%Y-%m-%d").to_string())]);
        }

        let response = request
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to get times: {}", e)))?;

        if response.status().as_u16() == 404 {
            return Err(ProviderError::NotFound(format!("Mosque {} not found", mosque_id)));
        }

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to get prayer times".to_string(),
            });
        }

        let data: serde_json::Value = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse: {}", e))
        })?;

        // Parse prayer times from API response
        // This is a simplified implementation - adjust according to actual Mawaqit API
        let date = date.unwrap_or_else(|| Utc::now().date_naive());
        let base_date = date.and_hms_opt(0, 0, 0).unwrap().and_local_timezone(Utc).unwrap();

        fn parse_time(date: chrono::DateTime<Utc>, time_str: &str) -> chrono::DateTime<Utc> {
            let parts: Vec<&str> = time_str.split(':').collect();
            let hour: u32 = parts.get(0).unwrap_or(&"0").parse().unwrap_or(0);
            let minute: u32 = parts.get(1).unwrap_or(&"0").parse().unwrap_or(0);
            date.date_naive().and_hms_opt(hour, minute, 0).unwrap().and_local_timezone(Utc).unwrap()
        }

        let get_time = |key: &str| -> chrono::DateTime<Utc> {
            let time_str = data.get(key).and_then(|v| v.as_str()).unwrap_or("00:00");
            parse_time(base_date, time_str)
        };

        let get_iqama = |key: &str| -> Option<chrono::DateTime<Utc>> {
            data.get(key).and_then(|v| v.as_str()).map(|t| parse_time(base_date, t))
        };

        Ok(PrayerTimes {
            date: base_date,
            fajr: Prayer {
                name: "Fajr".to_string(),
                adhan: get_time("fajr"),
                iqama: get_iqama("fajr_iqama"),
                custom_rakah_count: None,
            },
            dhuhr: Prayer {
                name: "Dhuhr".to_string(),
                adhan: get_time("dhuhr"),
                iqama: get_iqama("dhuhr_iqama"),
                custom_rakah_count: None,
            },
            asr: Prayer {
                name: "Asr".to_string(),
                adhan: get_time("asr"),
                iqama: get_iqama("asr_iqama"),
                custom_rakah_count: None,
            },
            maghrib: Prayer {
                name: "Maghrib".to_string(),
                adhan: get_time("maghrib"),
                iqama: get_iqama("maghrib_iqama"),
                custom_rakah_count: None,
            },
            isha: Prayer {
                name: "Isha".to_string(),
                adhan: get_time("isha"),
                iqama: get_iqama("isha_iqama"),
                custom_rakah_count: None,
            },
            jumuah: None,
            mosque_id: Some(mosque_id.to_string()),
            mosque_name: None,
            cached_at: Some(Utc::now()),
        })
    }

    async fn test_connection(&self) -> ProviderResult<ProviderTestResult> {
        let start = std::time::Instant::now();

        match self.ensure_initialized() {
            Ok(token) => {
                let response = self.client
                    .get(format!("{}/user/me", self.base_url))
                    .header("Authorization", format!("Bearer {}", token))
                    .send()
                    .await;

                match response {
                    Ok(resp) => {
                        let latency = start.elapsed().as_millis() as u64;
                        if resp.status().is_success() {
                            Ok(ProviderTestResult {
                                success: true,
                                message: "Connection successful".to_string(),
                                latency_ms: Some(latency),
                            })
                        } else {
                            Ok(ProviderTestResult {
                                success: false,
                                message: format!("Invalid token: {}", resp.status()),
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
            Err(e) => Ok(ProviderTestResult {
                success: false,
                message: format!("Not configured: {}", e),
                latency_ms: None,
            }),
        }
    }

    async fn get_mosque_details(&self, mosque_id: &str) -> ProviderResult<Mosque> {
        let token = self.ensure_initialized()?;

        let response = self.client
            .get(format!("{}/mosques/{}", self.base_url, mosque_id))
            .header("Authorization", format!("Bearer {}", token))
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to get details: {}", e)))?;

        if response.status().as_u16() == 404 {
            return Err(ProviderError::NotFound(format!("Mosque {} not found", mosque_id)));
        }

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to get mosque details".to_string(),
            });
        }

        let v: serde_json::Value = response.json().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to parse: {}", e))
        })?;

        Ok(Mosque {
            id: v.get("id").and_then(|v| v.as_str()).unwrap_or(mosque_id).to_string(),
            name: v.get("name").and_then(|v| v.as_str()).unwrap_or("Unknown").to_string(),
            address: v.get("address").and_then(|v| v.as_str()).map(|s| s.to_string()),
            city: v.get("city").and_then(|v| v.as_str()).map(|s| s.to_string()),
            country: v.get("country").and_then(|v| v.as_str()).map(|s| s.to_string()),
            latitude: v.get("latitude").and_then(|v| v.as_f64()),
            longitude: v.get("longitude").and_then(|v| v.as_f64()),
            is_favorite: false,
            last_accessed: None,
        })
    }
}
