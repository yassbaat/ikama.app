use chrono::{DateTime, NaiveDate, Utc};
use sqlx::{Pool, Sqlite};

use crate::models::*;

/// Database wrapper for all data access
pub struct Database {
    pool: Pool<Sqlite>,
}

impl Database {
    pub fn new(pool: Pool<Sqlite>) -> Self {
        Self { pool }
    }

    // Mosque operations

    pub async fn save_mosque(&self, mosque: &Mosque) -> anyhow::Result<()> {
        sqlx::query(
            r#"
            INSERT OR REPLACE INTO mosques 
            (id, name, address, city, country, latitude, longitude, is_favorite, last_accessed)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
            "#,
        )
        .bind(&mosque.id)
        .bind(&mosque.name)
        .bind(&mosque.address)
        .bind(&mosque.city)
        .bind(&mosque.country)
        .bind(mosque.latitude)
        .bind(mosque.longitude)
        .bind(mosque.is_favorite as i32)
        .bind(mosque.last_accessed.map(|d| d.to_rfc3339()))
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_mosque(&self, id: &str) -> anyhow::Result<Option<Mosque>> {
        let row = sqlx::query_as::<_, MosqueRow>(
            r#"
            SELECT id, name, address, city, country, latitude, longitude, is_favorite, last_accessed
            FROM mosques WHERE id = ?1
            "#,
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(|r| r.into()))
    }

    pub async fn get_favorite_mosques(&self) -> anyhow::Result<Vec<Mosque>> {
        let rows = sqlx::query_as::<_, MosqueRow>(
            r#"
            SELECT id, name, address, city, country, latitude, longitude, is_favorite, last_accessed
            FROM mosques WHERE is_favorite = 1 ORDER BY last_accessed DESC
            "#,
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(|r| r.into()).collect())
    }

    pub async fn set_favorite(&self, id: &str, favorite: bool) -> anyhow::Result<()> {
        sqlx::query(
            r#"
            UPDATE mosques SET is_favorite = ?1 WHERE id = ?2
            "#,
        )
        .bind(favorite as i32)
        .bind(id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    // Prayer times operations

    pub async fn save_prayer_times(&self, prayer_times: &PrayerTimes) -> anyhow::Result<()> {
        let date_str = prayer_times.date.format("%Y-%m-%d").to_string();
        let mosque_id = prayer_times.mosque_id.as_deref().unwrap_or("unknown");

        sqlx::query(
            r#"
            INSERT OR REPLACE INTO prayer_times 
            (mosque_id, date, 
             fajr_adhan, fajr_iqama, fajr_rakah,
             dhuhr_adhan, dhuhr_iqama, dhuhr_rakah,
             asr_adhan, asr_iqama, asr_rakah,
             maghrib_adhan, maghrib_iqama, maghrib_rakah,
             isha_adhan, isha_iqama, isha_rakah,
             jumuah_adhan, jumuah_iqama, jumuah_rakah,
             mosque_name, cached_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, ?22)
            "#,
        )
        .bind(mosque_id)
        .bind(&date_str)
        .bind(prayer_times.fajr.adhan.to_rfc3339())
        .bind(prayer_times.fajr.iqama.map(|d| d.to_rfc3339()))
        .bind(prayer_times.fajr.custom_rakah_count)
        .bind(prayer_times.dhuhr.adhan.to_rfc3339())
        .bind(prayer_times.dhuhr.iqama.map(|d| d.to_rfc3339()))
        .bind(prayer_times.dhuhr.custom_rakah_count)
        .bind(prayer_times.asr.adhan.to_rfc3339())
        .bind(prayer_times.asr.iqama.map(|d| d.to_rfc3339()))
        .bind(prayer_times.asr.custom_rakah_count)
        .bind(prayer_times.maghrib.adhan.to_rfc3339())
        .bind(prayer_times.maghrib.iqama.map(|d| d.to_rfc3339()))
        .bind(prayer_times.maghrib.custom_rakah_count)
        .bind(prayer_times.isha.adhan.to_rfc3339())
        .bind(prayer_times.isha.iqama.map(|d| d.to_rfc3339()))
        .bind(prayer_times.isha.custom_rakah_count)
        .bind(prayer_times.jumuah.as_ref().map(|p| p.adhan.to_rfc3339()))
        .bind(prayer_times.jumuah.as_ref().and_then(|p| p.iqama.map(|d| d.to_rfc3339())))
        .bind(prayer_times.jumuah.as_ref().and_then(|p| p.custom_rakah_count))
        .bind(prayer_times.mosque_name.as_deref())
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_prayer_times(
        &self,
        mosque_id: &str,
        date: NaiveDate,
    ) -> anyhow::Result<Option<PrayerTimes>> {
        let date_str = date.format("%Y-%m-%d").to_string();

        let row = sqlx::query_as::<_, PrayerTimesRow>(
            r#"
            SELECT * FROM prayer_times WHERE mosque_id = ?1 AND date = ?2
            "#,
        )
        .bind(mosque_id)
        .bind(&date_str)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.and_then(|r| r.to_prayer_times(mosque_id).ok()))
    }

    // Settings operations

    pub async fn set_setting(&self, key: &str, value: &str) -> anyhow::Result<()> {
        sqlx::query(
            r#"
            INSERT OR REPLACE INTO settings (key, value, updated_at)
            VALUES (?1, ?2, ?3)
            "#,
        )
        .bind(key)
        .bind(value)
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_setting(&self, key: &str) -> anyhow::Result<Option<String>> {
        let row: Option<(String,)> = sqlx::query_as(
            r#"
            SELECT value FROM settings WHERE key = ?1
            "#,
        )
        .bind(key)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(|r| r.0))
    }

    // Provider config operations

    pub async fn save_provider_config(&self, config: &ProviderConfig) -> anyhow::Result<()> {
        sqlx::query(
            r#"
            INSERT OR REPLACE INTO provider_configs (provider_id, settings, updated_at)
            VALUES (?1, ?2, ?3)
            "#,
        )
        .bind(&config.provider_id)
        .bind(serde_json::to_string(&config.settings)?)
        .bind(Utc::now().to_rfc3339())
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_provider_config(&self, provider_id: &str) -> anyhow::Result<Option<ProviderConfig>> {
        let row: Option<(String, String)> = sqlx::query_as(
            r#"
            SELECT provider_id, settings FROM provider_configs WHERE provider_id = ?1
            "#,
        )
        .bind(provider_id)
        .fetch_optional(&self.pool)
        .await?;

        match row {
            Some((id, settings)) => {
                let settings: serde_json::Value = serde_json::from_str(&settings)?;
                Ok(Some(ProviderConfig {
                    provider_id: id,
                    settings,
                }))
            }
            None => Ok(None),
        }
    }
}

// Database row structs

#[derive(sqlx::FromRow)]
struct MosqueRow {
    id: String,
    name: String,
    address: Option<String>,
    city: Option<String>,
    country: Option<String>,
    latitude: Option<f64>,
    longitude: Option<f64>,
    is_favorite: i32,
    last_accessed: Option<String>,
}

impl From<MosqueRow> for Mosque {
    fn from(row: MosqueRow) -> Self {
        Self {
            id: row.id,
            name: row.name,
            address: row.address,
            city: row.city,
            country: row.country,
            latitude: row.latitude,
            longitude: row.longitude,
            is_favorite: row.is_favorite != 0,
            last_accessed: row.last_accessed.and_then(|d| DateTime::parse_from_rfc3339(&d).ok().map(|dt| dt.with_timezone(&Utc))),
        }
    }
}

#[derive(sqlx::FromRow)]
#[allow(dead_code)]
struct PrayerTimesRow {
    mosque_id: String,
    date: String,
    fajr_adhan: String,
    fajr_iqama: Option<String>,
    fajr_rakah: Option<i32>,
    dhuhr_adhan: String,
    dhuhr_iqama: Option<String>,
    dhuhr_rakah: Option<i32>,
    asr_adhan: String,
    asr_iqama: Option<String>,
    asr_rakah: Option<i32>,
    maghrib_adhan: String,
    maghrib_iqama: Option<String>,
    maghrib_rakah: Option<i32>,
    isha_adhan: String,
    isha_iqama: Option<String>,
    isha_rakah: Option<i32>,
    jumuah_adhan: Option<String>,
    jumuah_iqama: Option<String>,
    jumuah_rakah: Option<i32>,
    mosque_name: Option<String>,
    cached_at: String,
}

impl PrayerTimesRow {
    fn to_prayer_times(&self, default_mosque_id: &str) -> anyhow::Result<PrayerTimes> {
        let date = NaiveDate::parse_from_str(&self.date, "%Y-%m-%d")?
            .and_hms_opt(0, 0, 0)
            .unwrap()
            .and_local_timezone(Utc)
            .unwrap();

        Ok(PrayerTimes {
            date,
            fajr: Prayer {
                name: "Fajr".to_string(),
                adhan: DateTime::parse_from_rfc3339(&self.fajr_adhan)?.with_timezone(&Utc),
                iqama: self.fajr_iqama.as_ref().and_then(|d| DateTime::parse_from_rfc3339(d).ok().map(|dt| dt.with_timezone(&Utc))),
                custom_rakah_count: self.fajr_rakah,
            },
            dhuhr: Prayer {
                name: "Dhuhr".to_string(),
                adhan: DateTime::parse_from_rfc3339(&self.dhuhr_adhan)?.with_timezone(&Utc),
                iqama: self.dhuhr_iqama.as_ref().and_then(|d| DateTime::parse_from_rfc3339(d).ok().map(|dt| dt.with_timezone(&Utc))),
                custom_rakah_count: self.dhuhr_rakah,
            },
            asr: Prayer {
                name: "Asr".to_string(),
                adhan: DateTime::parse_from_rfc3339(&self.asr_adhan)?.with_timezone(&Utc),
                iqama: self.asr_iqama.as_ref().and_then(|d| DateTime::parse_from_rfc3339(d).ok().map(|dt| dt.with_timezone(&Utc))),
                custom_rakah_count: self.asr_rakah,
            },
            maghrib: Prayer {
                name: "Maghrib".to_string(),
                adhan: DateTime::parse_from_rfc3339(&self.maghrib_adhan)?.with_timezone(&Utc),
                iqama: self.maghrib_iqama.as_ref().and_then(|d| DateTime::parse_from_rfc3339(d).ok().map(|dt| dt.with_timezone(&Utc))),
                custom_rakah_count: self.maghrib_rakah,
            },
            isha: Prayer {
                name: "Isha".to_string(),
                adhan: DateTime::parse_from_rfc3339(&self.isha_adhan)?.with_timezone(&Utc),
                iqama: self.isha_iqama.as_ref().and_then(|d| DateTime::parse_from_rfc3339(d).ok().map(|dt| dt.with_timezone(&Utc))),
                custom_rakah_count: self.isha_rakah,
            },
            jumuah: match &self.jumuah_adhan {
                Some(adhan) => Some(Prayer {
                    name: "Jumuah".to_string(),
                    adhan: DateTime::parse_from_rfc3339(adhan)?.with_timezone(&Utc),
                    iqama: self.jumuah_iqama.as_ref().and_then(|d| DateTime::parse_from_rfc3339(d).ok().map(|dt| dt.with_timezone(&Utc))),
                    custom_rakah_count: self.jumuah_rakah,
                }),
                None => None,
            },
            mosque_id: Some(default_mosque_id.to_string()),
            mosque_name: self.mosque_name.clone(),
            cached_at: DateTime::parse_from_rfc3339(&self.cached_at).ok().map(|dt| dt.with_timezone(&Utc)),
        })
    }
}
