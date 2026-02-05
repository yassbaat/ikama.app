use serde_json::Value;
use tauri::State;

use crate::db::Database;
use crate::models::ProviderConfig;

/// Get setting value
#[tauri::command]
pub async fn get_setting(key: String, db: State<'_, Database>) -> Result<Option<String>, String> {
    db.get_setting(&key)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Set setting value
#[tauri::command]
pub async fn set_setting(key: String, value: String, db: State<'_, Database>) -> Result<(), String> {
    db.set_setting(&key, &value)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Get provider configuration
#[tauri::command]
pub async fn get_provider_config(
    provider_id: String,
    db: State<'_, Database>,
) -> Result<Option<ProviderConfig>, String> {
    db.get_provider_config(&provider_id)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Save provider configuration
#[tauri::command]
pub async fn save_provider_config(
    config: ProviderConfig,
    db: State<'_, Database>,
) -> Result<(), String> {
    db.save_provider_config(&config)
        .await
        .map_err(|e| format!("Database error: {}", e))
}

/// Get all settings as JSON
#[tauri::command]
pub async fn get_all_settings(db: State<'_, Database>) -> Result<Value, String> {
    // Get common settings
    let mut settings = serde_json::Map::new();

    if let Ok(Some(value)) = db.get_setting("theme").await {
        settings.insert("theme".to_string(), Value::String(value));
    }

    if let Ok(Some(value)) = db.get_setting("language").await {
        settings.insert("language".to_string(), Value::String(value));
    }

    if let Ok(Some(value)) = db.get_setting("notification_enabled").await {
        settings.insert(
            "notification_enabled".to_string(),
            Value::Bool(value == "true"),
        );
    }

    Ok(Value::Object(settings))
}

/// Save all settings from JSON
#[tauri::command]
pub async fn save_all_settings(settings: Value, db: State<'_, Database>) -> Result<(), String> {
    if let Some(theme) = settings.get("theme").and_then(|v| v.as_str()) {
        db.set_setting("theme", theme).await.ok();
    }

    if let Some(lang) = settings.get("language").and_then(|v| v.as_str()) {
        db.set_setting("language", lang).await.ok();
    }

    if let Some(notif) = settings.get("notification_enabled").and_then(|v| v.as_bool()) {
        db.set_setting("notification_enabled", &notif.to_string())
            .await
            .ok();
    }

    Ok(())
}
