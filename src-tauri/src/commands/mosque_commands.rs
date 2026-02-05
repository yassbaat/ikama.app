use tauri::State;

use crate::db::Database;
use crate::models::*;
use crate::providers::*;

/// Search for mosques - uses Mawaqit provider by default
#[tauri::command]
pub async fn search_mosques(
    query: String,
    country: Option<String>,
    db: State<'_, Database>,
) -> Result<MosqueSearchResult, String> {
    // Check if user has configured a provider
    let community_config = db.get_provider_config(PROVIDER_COMMUNITY_WRAPPER).await.ok().flatten();
    let official_config = db.get_provider_config(PROVIDER_OFFICIAL_API).await.ok().flatten();
    
    let provider_config = community_config.or(official_config);

    let mut external_results: Vec<Mosque> = Vec::new();

    // Try configured provider first
    if let Some(config) = provider_config {
        let result = match config.provider_id.as_str() {
            PROVIDER_COMMUNITY_WRAPPER => {
                let mut provider = CommunityWrapperProvider::new();
                provider.initialize(config.settings).await.ok();
                provider.search_mosques(&query, None).await.ok()
            }
            PROVIDER_OFFICIAL_API => {
                let mut provider = OfficialApiProvider::new();
                provider.initialize(config.settings).await.ok();
                provider.search_mosques(&query, None).await.ok()
            }
            _ => None,
        };

        if let Some(results) = result {
            external_results = results;
        }
    }

    // If no external results, try Mawaqit as fallback
    if external_results.is_empty() {
        let mut mawaqit = MawaqitProvider::new();
        // Use provided country or default to FR
        let country_config = country.map(|c| {
            serde_json::json!({"default_country": c})
        }).unwrap_or_else(|| serde_json::json!({"default_country": "FR"}));
        
        if mawaqit.initialize(country_config).await.is_ok() {
            if let Ok(results) = mawaqit.search_mosques(&query, None).await {
                external_results = results;
            }
        }
    }

    // Also search local favorites
    let favorites = db
        .get_favorite_mosques()
        .await
        .map_err(|e| format!("Database error: {}", e))?;

    let local_results: Vec<Mosque> = favorites
        .clone()
        .into_iter()
        .filter(|m| {
            m.name.to_lowercase().contains(&query.to_lowercase())
                || m.city
                    .as_ref()
                    .map(|c| c.to_lowercase().contains(&query.to_lowercase()))
                    .unwrap_or(false)
        })
        .collect();

    // Merge results
    let mut all_results = external_results;
    for fav in local_results {
        if !all_results.iter().any(|m| m.id == fav.id) {
            all_results.push(fav);
        }
    }

    // Mark favorites
    for mosque in &mut all_results {
        if favorites.iter().any(|f| f.id == mosque.id) {
            mosque.is_favorite = true;
        }
    }

    let total = all_results.len();

    Ok(MosqueSearchResult {
        mosques: all_results,
        total,
    })
}

/// Get favorite mosques
#[tauri::command]
pub async fn get_favorite_mosques(db: State<'_, Database>) -> Result<Vec<Mosque>, String> {
    db.get_favorite_mosques()
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Add a mosque to favorites
#[tauri::command]
pub async fn add_favorite_mosque(
    mosque: Mosque,
    db: State<'_, Database>,
) -> Result<(), String> {
    let mosque = Mosque {
        is_favorite: true,
        last_accessed: Some(chrono::Utc::now()),
        ..mosque
    };

    db.save_mosque(&mosque)
        .await
        .map_err(|e| format!("Database error: {}", e))?;

    db.set_favorite(&mosque.id, true)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Remove a mosque from favorites
#[tauri::command]
pub async fn remove_favorite_mosque(
    mosque_id: String,
    db: State<'_, Database>,
) -> Result<(), String> {
    db.set_favorite(&mosque_id, false)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Get mosque details
#[tauri::command]
pub async fn get_mosque_details(
    mosque_id: String,
    db: State<'_, Database>,
) -> Result<Option<Mosque>, String> {
    db.get_mosque(&mosque_id)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Get prayer times for a mosque
/// Optional date parameter in format "YYYY-MM-DD" for future/past dates
#[tauri::command]
pub async fn get_prayer_times_for_mosque(
    mosque_id: String,
    country: Option<String>,
    date: Option<String>,
    db: State<'_, Database>,
) -> Result<PrayerTimes, String> {
    use chrono::NaiveDate;

    let target_date = match date {
        Some(d) => NaiveDate::parse_from_str(&d, "%Y-%m-%d")
            .map_err(|e| format!("Invalid date format. Use YYYY-MM-DD: {}", e))?,
        None => chrono::Local::now().date_naive(),
    };

    // Try to get from cache first
    if let Ok(Some(cached)) = db.get_prayer_times(&mosque_id, target_date).await {
        return Ok(cached);
    }

    // Try external providers
    let result = if let Ok(Some(config)) = db.get_provider_config(PROVIDER_COMMUNITY_WRAPPER).await
    {
        let mut provider = CommunityWrapperProvider::new();
        if provider.initialize(config.settings).await.is_ok() {
            provider.get_prayer_times(&mosque_id, Some(target_date)).await.ok()
        } else {
            None
        }
    } else if let Ok(Some(config)) = db.get_provider_config(PROVIDER_OFFICIAL_API).await {
        let mut provider = OfficialApiProvider::new();
        if provider.initialize(config.settings).await.is_ok() {
            provider.get_prayer_times(&mosque_id, Some(target_date)).await.ok()
        } else {
            None
        }
    } else {
        None
    };

    // Try Mawaqit as fallback
    let result = if result.is_none() {
        let mut mawaqit = MawaqitProvider::new();
        let country_config = country
            .map(|c| serde_json::json!({"default_country": c}))
            .unwrap_or_else(|| serde_json::json!({"default_country": "FR"}));

        if mawaqit.initialize(country_config).await.is_ok() {
            mawaqit.get_prayer_times(&mosque_id, Some(target_date)).await.ok()
        } else {
            None
        }
    } else {
        result
    };

    match result {
        Some(times) => {
            // Cache the result
            let _ = db.save_prayer_times(&times).await;
            Ok(times)
        }
        None => Err(
            format!("No prayer times found for {}. Please configure a provider in settings or try again.", target_date)
        ),
    }
}

/// Fetch prayer times for a specific date from a mawaqit URL
/// This fetches fresh data from the calendar regardless of cache
#[tauri::command]
pub async fn fetch_prayer_times_for_date(
    mawaqit_url: String,
    date: String,
) -> Result<PrayerTimes, String> {
    use chrono::NaiveDate;
    
    let target_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d")
        .map_err(|e| format!("Invalid date format. Use YYYY-MM-DD: {}", e))?;

    let mut mawaqit = MawaqitProvider::new();
    
    // Extract slug from URL (e.g., https://mawaqit.net/en/m/mosque-name -> mosque-name)
    let slug = mawaqit_url
        .split('/')
        .last()
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .or_else(|| {
            mawaqit_url
                .split('/')
                .rev()
                .nth(1)
                .filter(|s| !s.is_empty())
                .map(|s| s.to_string())
        })
        .ok_or_else(|| "Invalid mawaqit URL".to_string())?;

    log::info!("Fetching prayer times for {} on date {}", slug, target_date);

    mawaqit.initialize(serde_json::json!({"default_country": "FR"})).await
        .map_err(|e| format!("Failed to initialize provider: {}", e))?;
    
    mawaqit.get_prayer_times(&slug, Some(target_date)).await
        .map_err(|e| format!("Failed to fetch prayer times: {}", e))
}

/// Test provider connection
#[tauri::command]
pub async fn test_provider_connection(
    provider_id: String,
    config: serde_json::Value,
) -> Result<ProviderTestResult, String> {
    use crate::providers::*;

    let result: Result<ProviderTestResult, String> = match provider_id.as_str() {
        "mawaqit" => {
            let mut provider = MawaqitProvider::new();
            provider.initialize(config).await
                .map_err(|e| format!("Failed to initialize: {}", e))?;
            provider.test_connection().await
                .map_err(|e| format!("Connection test failed: {}", e))
        }
        PROVIDER_OFFICIAL_API => {
            let mut provider = OfficialApiProvider::new();
            provider.initialize(config).await
                .map_err(|e| format!("Failed to initialize: {}", e))?;
            provider.test_connection().await
                .map_err(|e| format!("Connection test failed: {}", e))
        }
        PROVIDER_COMMUNITY_WRAPPER => {
            let mut provider = CommunityWrapperProvider::new();
            provider.initialize(config).await
                .map_err(|e| format!("Failed to initialize: {}", e))?;
            provider.test_connection().await
                .map_err(|e| format!("Connection test failed: {}", e))
        }
        PROVIDER_SCRAPING => {
            let mut provider = ScrapingProvider::new();
            provider.initialize(config).await
                .map_err(|e| format!("Failed to initialize: {}", e))?;
            provider.test_connection().await
                .map_err(|e| format!("Connection test failed: {}", e))
        }
        _ => Err(format!("Unknown provider: {}", provider_id)),
    };

    result
}

/// Get available providers list including Mawaqit
#[tauri::command]
pub async fn get_available_providers() -> Vec<ProviderInfo> {
    let mawaqit = MawaqitProvider::new();

    vec![
        ProviderInfo {
            id: "mawaqit".to_string(),
            name: "Mawaqit (Recommended)".to_string(),
            description: "Official Mawaqit.net - No API key required, works worldwide".to_string(),
            config_schema: mawaqit.config_schema(),
        },
        ProviderInfo {
            id: PROVIDER_OFFICIAL_API.to_string(),
            name: "Mawaqit Official API".to_string(),
            description: "Direct access to Mawaqit prayer times API (requires API token)".to_string(),
            config_schema: vec![
                ConfigField::new("api_token", "API Token", ConfigFieldType::Password)
                    .required()
                    .description("Your Mawaqit API token"),
                ConfigField::new("base_url", "Base URL", ConfigFieldType::Url)
                    .default_value("https://mawaqit.net/api")
                    .description("Optional: Custom API base URL"),
            ],
        },
        ProviderInfo {
            id: PROVIDER_COMMUNITY_WRAPPER.to_string(),
            name: "Community Wrapper API".to_string(),
            description: "Community-provided REST API wrapper for prayer times data".to_string(),
            config_schema: vec![
                ConfigField::new("base_url", "API Base URL", ConfigFieldType::Url)
                    .required()
                    .description("The base URL of the community API"),
                ConfigField::new("api_key", "API Key", ConfigFieldType::Password)
                    .description("Optional API key for authentication"),
            ],
        },
        ProviderInfo {
            id: PROVIDER_SCRAPING.to_string(),
            name: "HTML Scraping".to_string(),
            description: "Fallback provider that scrapes prayer times from mosque websites".to_string(),
            config_schema: vec![
                ConfigField::new("base_url", "Mosque Website URL", ConfigFieldType::Url)
                    .description("The URL of the mosque's prayer times page"),
                ConfigField::new("rate_limit", "Rate Limit (ms)", ConfigFieldType::Number)
                    .default_value("1000")
                    .description("Delay between requests in milliseconds"),
            ],
        },
    ]
}

/// Get active provider info
#[tauri::command]
pub async fn get_active_provider(db: State<'_, Database>) -> Result<Option<ProviderInfo>, String> {
    // Check Mawaqit (default)
    let mawaqit = MawaqitProvider::new();
    
    // Check other providers
    if let Ok(Some(_)) = db.get_provider_config(PROVIDER_OFFICIAL_API).await {
        let provider = OfficialApiProvider::new();
        return Ok(Some(ProviderInfo {
            id: provider.id().to_string(),
            name: provider.name().to_string(),
            description: provider.description().to_string(),
            config_schema: provider.config_schema(),
        }));
    }

    if let Ok(Some(_)) = db.get_provider_config(PROVIDER_COMMUNITY_WRAPPER).await {
        let provider = CommunityWrapperProvider::new();
        return Ok(Some(ProviderInfo {
            id: provider.id().to_string(),
            name: provider.name().to_string(),
            description: provider.description().to_string(),
            config_schema: provider.config_schema(),
        }));
    }

    // Return Mawaqit as default
    Ok(Some(ProviderInfo {
        id: mawaqit.id().to_string(),
        name: mawaqit.name().to_string(),
        description: mawaqit.description().to_string(),
        config_schema: mawaqit.config_schema(),
    }))
}
