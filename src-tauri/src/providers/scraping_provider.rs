use async_trait::async_trait;
use chrono::{NaiveDate, Utc};
use reqwest::Client;
use scraper::{Html, Selector};
use serde_json::Value;

use crate::models::*;
use crate::providers::{PrayerDataProvider, ProviderError, ProviderResult};

/// HTML Scraping Provider (Provider C)
/// Fallback that scrapes prayer times from mosque websites
pub struct ScrapingProvider {
    client: Client,
    base_url: Option<String>,
    rate_limit_delay_ms: u64,
}

impl ScrapingProvider {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
                .build()
                .unwrap(),
            base_url: None,
            rate_limit_delay_ms: 1000, // 1 second between requests
        }
    }

    async fn rate_limit(&self) {
        tokio::time::sleep(tokio::time::Duration::from_millis(self.rate_limit_delay_ms)).await;
    }

    fn parse_time_from_text(&self, text: &str) -> Option<String> {
        // Try to find time patterns like "05:30", "5:30 AM", "17:30", etc.
        let re = regex::Regex::new(r"(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?").ok()?;
        re.captures(text).map(|cap| {
            let hour = cap.get(1)?.as_str();
            let minute = cap.get(2)?.as_str();
            Some(format!("{}:{}", hour, minute))
        })?
    }
}

#[async_trait]
impl PrayerDataProvider for ScrapingProvider {
    fn id(&self) -> &str {
        PROVIDER_SCRAPING
    }

    fn name(&self) -> &str {
        "HTML Scraping"
    }

    fn description(&self) -> &str {
        "Fallback provider that scrapes prayer times from mosque websites"
    }

    fn config_schema(&self) -> Vec<ConfigField> {
        vec![
            ConfigField::new("base_url", "Mosque Website URL", ConfigFieldType::Url)
                .description("The URL of the mosque's prayer times page"),
            ConfigField::new("rate_limit", "Rate Limit (ms)", ConfigFieldType::Number)
                .default_value("1000")
                .description("Delay between requests in milliseconds"),
        ]
    }

    async fn initialize(&mut self, config: Value) -> ProviderResult<()> {
        self.base_url = config["base_url"].as_str().map(|s| s.to_string());
        if let Some(delay) = config["rate_limit"].as_u64() {
            self.rate_limit_delay_ms = delay;
        }
        Ok(())
    }

    async fn search_mosques(&self, _query: &str, _location: Option<&GeoLocation>) -> ProviderResult<Vec<Mosque>> {
        // Scraping provider doesn't support searching
        Err(ProviderError::Other(
            "Scraping provider doesn't support mosque search".to_string(),
        ))
    }

    async fn get_nearby_mosques(&self, _location: &GeoLocation, _radius_km: f64) -> ProviderResult<Vec<Mosque>> {
        // Scraping provider doesn't support nearby search
        Err(ProviderError::Other(
            "Scraping provider doesn't support nearby search".to_string(),
        ))
    }

    async fn get_prayer_times(&self, _mosque_id: &str, date: Option<NaiveDate>) -> ProviderResult<PrayerTimes> {
        let base_url = self.base_url.as_ref().ok_or_else(|| {
            ProviderError::InvalidConfig("Base URL not configured".to_string())
        })?;

        self.rate_limit().await;

        let url = if let Some(d) = date {
            format!("{}?date={}", base_url, d.format("%Y-%m-%d"))
        } else {
            base_url.clone()
        };

        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| ProviderError::Network(format!("Failed to fetch: {}", e)))?;

        if !response.status().is_success() {
            return Err(ProviderError::Server {
                status_code: response.status().as_u16(),
                message: "Failed to fetch page".to_string(),
            });
        }

        let html = response.text().await.map_err(|e| {
            ProviderError::Parse(format!("Failed to read response: {}", e))
        })?;

        let document = Html::parse_document(&html);

        // Try to find prayer times in the HTML
        // This is a generic implementation - specific selectors would depend on the site structure
        let prayer_names = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
        let mut prayers: Vec<(String, Option<String>)> = Vec::new();

        // Try common CSS selectors for prayer times
        let selectors_to_try = [
            "table.prayer-times td",
            ".prayer-time",
            "[data-prayer]",
            ".salah-time",
            ".adhan-time",
        ];

        for selector_str in &selectors_to_try {
            if let Ok(selector) = Selector::parse(selector_str) {
                let elements: Vec<_> = document.select(&selector).collect();
                if elements.len() >= 5 {
                    for (i, element) in elements.iter().enumerate().take(5) {
                        let text = element.text().collect::<String>();
                        if let Some(time) = self.parse_time_from_text(&text) {
                            prayers.push((prayer_names[i].to_string(), Some(time)));
                        }
                    }
                    break;
                }
            }
        }

        if prayers.len() < 5 {
            return Err(ProviderError::Parse(
                "Could not find prayer times in page".to_string(),
            ));
        }

        let date = date.unwrap_or_else(|| Utc::now().date_naive());
        let base_date = date.and_hms_opt(0, 0, 0).unwrap().and_local_timezone(Utc).unwrap();

        fn parse_time(date: chrono::DateTime<Utc>, time_str: &str) -> chrono::DateTime<Utc> {
            let parts: Vec<&str> = time_str.split(':').collect();
            let hour: u32 = parts.get(0).unwrap_or(&"0").parse().unwrap_or(0);
            let minute: u32 = parts.get(1).unwrap_or(&"0").parse().unwrap_or(0);
            date.date_naive().and_hms_opt(hour, minute, 0).unwrap().and_local_timezone(Utc).unwrap()
        }

        Ok(PrayerTimes {
            date: base_date,
            fajr: Prayer {
                name: "Fajr".to_string(),
                adhan: parse_time(base_date, prayers[0].1.as_deref().unwrap_or("05:00")),
                iqama: None,
                custom_rakah_count: None,
            },
            dhuhr: Prayer {
                name: "Dhuhr".to_string(),
                adhan: parse_time(base_date, prayers[1].1.as_deref().unwrap_or("12:00")),
                iqama: None,
                custom_rakah_count: None,
            },
            asr: Prayer {
                name: "Asr".to_string(),
                adhan: parse_time(base_date, prayers[2].1.as_deref().unwrap_or("15:00")),
                iqama: None,
                custom_rakah_count: None,
            },
            maghrib: Prayer {
                name: "Maghrib".to_string(),
                adhan: parse_time(base_date, prayers[3].1.as_deref().unwrap_or("18:00")),
                iqama: None,
                custom_rakah_count: None,
            },
            isha: Prayer {
                name: "Isha".to_string(),
                adhan: parse_time(base_date, prayers[4].1.as_deref().unwrap_or("19:30")),
                iqama: None,
                custom_rakah_count: None,
            },
            jumuah: None,
            mosque_id: Some("scraped".to_string()),
            mosque_name: None,
            cached_at: Some(Utc::now()),
        })
    }

    async fn test_connection(&self) -> ProviderResult<ProviderTestResult> {
        let start = std::time::Instant::now();

        match &self.base_url {
            Some(url) => {
                self.rate_limit().await;

                match self.client.get(url).send().await {
                    Ok(resp) => {
                        let latency = start.elapsed().as_millis() as u64;
                        if resp.status().is_success() {
                            Ok(ProviderTestResult {
                                success: true,
                                message: "Page accessible".to_string(),
                                latency_ms: Some(latency),
                            })
                        } else {
                            Ok(ProviderTestResult {
                                success: false,
                                message: format!("Page returned: {}", resp.status()),
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
            None => Ok(ProviderTestResult {
                success: false,
                message: "No URL configured".to_string(),
                latency_ms: None,
            }),
        }
    }

    async fn get_mosque_details(&self, _mosque_id: &str) -> ProviderResult<Mosque> {
        Err(ProviderError::Other(
            "Scraping provider doesn't support mosque details".to_string(),
        ))
    }
}
