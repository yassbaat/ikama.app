use sqlx::{Pool, Sqlite, SqlitePool};
use std::path::Path;

pub async fn run_migrations(pool: &Pool<Sqlite>) -> anyhow::Result<()> {
    // Create tables if they don't exist
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS mosques (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            city TEXT,
            country TEXT,
            latitude REAL,
            longitude REAL,
            is_favorite INTEGER DEFAULT 0,
            last_accessed TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS prayer_times (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            mosque_id TEXT NOT NULL,
            date TEXT NOT NULL,
            fajr_adhan TEXT NOT NULL,
            fajr_iqama TEXT,
            fajr_rakah INTEGER,
            dhuhr_adhan TEXT NOT NULL,
            dhuhr_iqama TEXT,
            dhuhr_rakah INTEGER,
            asr_adhan TEXT NOT NULL,
            asr_iqama TEXT,
            asr_rakah INTEGER,
            maghrib_adhan TEXT NOT NULL,
            maghrib_iqama TEXT,
            maghrib_rakah INTEGER,
            isha_adhan TEXT NOT NULL,
            isha_iqama TEXT,
            isha_rakah INTEGER,
            jumuah_adhan TEXT,
            jumuah_iqama TEXT,
            jumuah_rakah INTEGER,
            mosque_name TEXT,
            cached_at TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (mosque_id) REFERENCES mosques(id),
            UNIQUE(mosque_id, date)
        )
        "#,
    )
    .execute(pool)
    .await?;

    // Migration: Add mosque_name column if it doesn't exist
    sqlx::query(
        r#"
        ALTER TABLE prayer_times ADD COLUMN mosque_name TEXT
        "#,
    )
    .execute(pool)
    .await.ok(); // Ignore error if column already exists

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS provider_configs (
            provider_id TEXT PRIMARY KEY,
            settings TEXT NOT NULL,
            is_active INTEGER DEFAULT 0,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
        "#,
    )
    .execute(pool)
    .await?;

    // Create indexes
    sqlx::query(
        r#"
        CREATE INDEX IF NOT EXISTS idx_mosques_favorite ON mosques(is_favorite)
        "#,
    )
    .execute(pool)
    .await?;

    sqlx::query(
        r#"
        CREATE INDEX IF NOT EXISTS idx_prayer_times_mosque_date ON prayer_times(mosque_id, date)
        "#,
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn create_database(db_path: &str) -> anyhow::Result<Pool<Sqlite>> {
    // Ensure parent directory exists
    if let Some(parent) = Path::new(db_path).parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Create the database connection
    let database_url = format!("sqlite:{}", db_path);
    let pool = SqlitePool::connect(&database_url).await?;
    
    // Run migrations
    run_migrations(&pool).await?;

    Ok(pool)
}
