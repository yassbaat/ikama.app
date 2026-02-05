use async_trait::async_trait;
use chrono::{NaiveDate, Utc};
use serde_json::Value;

use crate::models::*;
use crate::providers::{PrayerDataProvider, ProviderError, ProviderResult};

/// Fallback provider that chains multiple providers
/// Tries each provider in order until one succeeds
pub struct FallbackProvider {
    providers: Vec<Box<dyn PrayerDataProvider>>,
}

impl FallbackProvider {
    pub fn new() -> Self {
        Self {
            providers: Vec::new(),
        }
    }

    pub fn add_provider(&mut self, provider: Box<dyn PrayerDataProvider>) {
        self.providers.push(provider);
    }

    pub fn builder() -> FallbackProviderBuilder {
        FallbackProviderBuilder::new()
    }
}

pub struct FallbackProviderBuilder {
    providers: Vec<Box<dyn PrayerDataProvider>>,
}

impl FallbackProviderBuilder {
    pub fn new() -> Self {
        Self {
            providers: Vec::new(),
        }
    }

    pub fn add(mut self, provider: Box<dyn PrayerDataProvider>) -> Self {
        self.providers.push(provider);
        self
    }

    pub fn build(self) -> FallbackProvider {
        FallbackProvider {
            providers: self.providers,
        }
    }
}

impl Default for FallbackProviderBuilder {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl PrayerDataProvider for FallbackProvider {
    fn id(&self) -> &str {
        "fallback"
    }

    fn name(&self) -> &str {
        "Fallback Chain"
    }

    fn description(&self) -> &str {
        "Automatically tries multiple providers in order"
    }

    fn config_schema(&self) -> Vec<ConfigField> {
        vec![]
    }

    async fn initialize(&mut self, _config: Value) -> ProviderResult<()> {
        // Individual providers should be initialized separately
        Ok(())
    }

    async fn search_mosques(&self, query: &str, location: Option<&GeoLocation>) -> ProviderResult<Vec<Mosque>> {
        let mut last_error = None;

        for provider in &self.providers {
            match provider.search_mosques(query, location).await {
                Ok(results) => return Ok(results),
                Err(e) => last_error = Some(e),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            ProviderError::Other("No providers available".to_string())
        }))
    }

    async fn get_nearby_mosques(&self, location: &GeoLocation, radius_km: f64) -> ProviderResult<Vec<Mosque>> {
        let mut last_error = None;

        for provider in &self.providers {
            match provider.get_nearby_mosques(location, radius_km).await {
                Ok(results) => return Ok(results),
                Err(e) => last_error = Some(e),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            ProviderError::Other("No providers available".to_string())
        }))
    }

    async fn get_prayer_times(&self, mosque_id: &str, date: Option<NaiveDate>) -> ProviderResult<PrayerTimes> {
        let mut last_error = None;

        for provider in &self.providers {
            match provider.get_prayer_times(mosque_id, date).await {
                Ok(times) => return Ok(times),
                Err(e) => last_error = Some(e),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            ProviderError::Other("No providers available".to_string())
        }))
    }

    async fn test_connection(&self) -> ProviderResult<ProviderTestResult> {
        let mut all_success = true;
        let mut messages = Vec::new();

        for provider in &self.providers {
            match provider.test_connection().await {
                Ok(result) => {
                    messages.push(format!("{}: {}", provider.name(), result.message));
                    if !result.success {
                        all_success = false;
                    }
                }
                Err(e) => {
                    messages.push(format!("{}: Failed - {}", provider.name(), e));
                    all_success = false;
                }
            }
        }

        Ok(ProviderTestResult {
            success: all_success,
            message: messages.join("; "),
            latency_ms: None,
        })
    }

    async fn get_mosque_details(&self, mosque_id: &str) -> ProviderResult<Mosque> {
        let mut last_error = None;

        for provider in &self.providers {
            match provider.get_mosque_details(mosque_id).await {
                Ok(mosque) => return Ok(mosque),
                Err(e) => last_error = Some(e),
            }
        }

        Err(last_error.unwrap_or_else(|| {
            ProviderError::Other("No providers available".to_string())
        }))
    }
}
