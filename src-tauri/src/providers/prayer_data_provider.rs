use async_trait::async_trait;
use serde_json::Value;

use crate::models::*;

/// Error type for provider operations
#[derive(Debug, thiserror::Error)]
pub enum ProviderError {
    #[error("Network error: {0}")]
    Network(String),
    #[error("Server error: {status_code} - {message}")]
    Server { status_code: u16, message: String },
    #[error("Parse error: {0}")]
    Parse(String),
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),
    #[error("Other: {0}")]
    Other(String),
}

pub type ProviderResult<T> = Result<T, ProviderError>;

/// Abstract interface for all prayer data providers
#[async_trait]
pub trait PrayerDataProvider: Send + Sync {
    /// Provider unique identifier
    fn id(&self) -> &str;

    /// Provider display name
    fn name(&self) -> &str;

    /// Provider description
    fn description(&self) -> &str;

    /// Configuration schema for settings UI
    fn config_schema(&self) -> Vec<ConfigField>;

    /// Initialize provider with configuration
    async fn initialize(&mut self, config: Value) -> ProviderResult<()>;

    /// Search mosques by query string
    async fn search_mosques(&self, query: &str, location: Option<&GeoLocation>) -> ProviderResult<Vec<Mosque>>;

    /// Get mosques near a location
    async fn get_nearby_mosques(&self, location: &GeoLocation, radius_km: f64) -> ProviderResult<Vec<Mosque>>;

    /// Fetch prayer times for a specific mosque
    async fn get_prayer_times(&self, mosque_id: &str, date: Option<chrono::NaiveDate>) -> ProviderResult<PrayerTimes>;

    /// Test connectivity with current configuration
    async fn test_connection(&self) -> ProviderResult<ProviderTestResult>;

    /// Get mosque details
    async fn get_mosque_details(&self, mosque_id: &str) -> ProviderResult<Mosque>;
}

/// Provider factory
pub struct ProviderFactory;

impl ProviderFactory {
    pub fn create_official_api() -> Box<dyn PrayerDataProvider> {
        Box::new(crate::providers::OfficialApiProvider::new())
    }

    pub fn create_community_wrapper() -> Box<dyn PrayerDataProvider> {
        Box::new(crate::providers::CommunityWrapperProvider::new())
    }

    pub fn create_scraping() -> Box<dyn PrayerDataProvider> {
        Box::new(crate::providers::ScrapingProvider::new())
    }
}
