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
            
            // Initialize database with better error handling
            let database_result: anyhow::Result<(Database, String)> = tauri::async_runtime::block_on(async move {
                let app_dir = match dirs::data_dir() {
                    Some(dir) => dir.join("iqamah"),
                    None => {
                        return Err(anyhow::anyhow!("Could not find data directory"));
                    }
                };

                // Ensure the directory exists
                if let Err(e) = std::fs::create_dir_all(&app_dir) {
                    return Err(anyhow::anyhow!("Failed to create app directory: {}", e));
                }

                let db_path = app_dir.join("iqamah.db");
                let db_path_str = db_path.to_string_lossy().to_string();
                
                log::info!("Initializing database at: {}", db_path_str);
                
                match db::migrations::create_database(&db_path_str).await {
                    Ok(pool) => Ok((Database::new(pool), db_path_str)),
                    Err(e) => Err(anyhow::anyhow!("Database creation failed: {}", e)),
                }
            });

            match database_result {
                Ok((database, path)) => {
                    log::info!("Database initialized successfully at: {}", path);
                    app_handle.manage(database);
                    
                    // Store the database path for debugging
                    let db_path_clone = path.clone();
                    tauri::async_runtime::spawn(async move {
                        log::info!("Database persistence path: {}", db_path_clone);
                    });
                }
                Err(e) => {
                    log::error!("Failed to initialize database: {}", e);
                    // Create a fallback in-memory database as last resort
                    let fallback_result: anyhow::Result<Database> = tauri::async_runtime::block_on(async {
                        let pool = db::migrations::create_database(":memory:").await
                            .map_err(|e| anyhow::anyhow!("Failed to create in-memory DB: {}", e))?;
                        Ok(Database::new(pool))
                    });
                    
                    match fallback_result {
                        Ok(database) => {
                            log::warn!("Using in-memory database as fallback - data will NOT persist!");
                            app_handle.manage(database);
                        }
                        Err(e2) => {
                            log::error!("Critical: Failed to create any database: {}", e2);
                            panic!("Cannot start application without database");
                        }
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
            commands::save_selected_mosque,
            commands::get_selected_mosque,
            commands::check_database_health,
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
