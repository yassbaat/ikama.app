use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

use super::PrayerTimes;

/// Mosque entity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Mosque {
    pub id: String,
    pub name: String,
    pub address: Option<String>,
    pub city: Option<String>,
    pub country: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub is_favorite: bool,
    pub last_accessed: Option<DateTime<Utc>>,
}

impl Mosque {
    pub fn new(id: String, name: String) -> Self {
        Self {
            id,
            name,
            address: None,
            city: None,
            country: None,
            latitude: None,
            longitude: None,
            is_favorite: false,
            last_accessed: None,
        }
    }
}

/// Mosque with prayer times
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MosqueWithPrayerTimes {
    #[serde(flatten)]
    pub mosque: Mosque,
    pub prayer_times: Option<PrayerTimes>,
}

/// Search result for mosques
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MosqueSearchResult {
    pub mosques: Vec<Mosque>,
    pub total: usize,
}

/// Favorite mosque entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FavoriteMosque {
    pub mosque: Mosque,
    pub added_at: DateTime<Utc>,
    pub is_active: bool,
}
