// Prevents additional console window on Windows in release
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use tauri::Manager;

mod commands;
mod db;
mod models;
mod providers;
mod services;

use db::Database;

fn main() {
    env_logger::init();

    tauri::Builder::default()
        .setup(|app| {
            let app_handle = app.handle();
            
            // Initialize database
            let database_result: anyhow::Result<Database> = tauri::async_runtime::block_on(async move {
                let app_dir = match dirs::data_dir() {
                    Some(dir) => dir.join("iqamah"),
                    None => {
                        return Err(anyhow::anyhow!("Could not find data directory"));
                    }
                };

                std::fs::create_dir_all(&app_dir)?;

                let db_path = app_dir.join("iqamah.db");
                let db_path_str = db_path.to_string_lossy().to_string();
                
                log::info!("Initializing database at: {}", db_path_str);
                
                let pool = db::migrations::create_database(&db_path_str).await?;
                Ok(Database::new(pool))
            });

            match database_result {
                Ok(database) => {
                    log::info!("Database initialized successfully");
                    app_handle.manage(database);
                }
                Err(e) => {
                    log::error!("Failed to initialize database: {}", e);
                    // Create a fallback in-memory database
                    let fallback_result: anyhow::Result<Database> = tauri::async_runtime::block_on(async {
                        let pool = db::migrations::create_database(":memory:").await?;
                        Ok(Database::new(pool))
                    });
                    
                    if let Ok(database) = fallback_result {
                        log::warn!("Using in-memory database as fallback");
                        app_handle.manage(database);
                    }
                }
            }
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Mosque commands
            commands::search_mosques,
            commands::get_favorite_mosques,
            commands::add_favorite_mosque,
            commands::remove_favorite_mosque,
            commands::get_mosque_details,
            commands::get_prayer_times_for_mosque,
            commands::fetch_prayer_times_for_date,
            commands::get_active_provider,
            commands::get_available_providers,
            commands::test_provider_connection,
            // Prayer commands
            commands::get_next_prayer,
            commands::get_prayer_times,
            commands::get_all_countdowns,
            commands::estimate_rakah,
            commands::calculate_travel_prediction,
            commands::get_countdown,
            commands::format_duration,
            // Settings commands
            commands::get_setting,
            commands::set_setting,
            commands::get_provider_config,
            commands::save_provider_config,
            commands::get_all_settings,
            commands::save_all_settings,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
