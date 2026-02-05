use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// Notification configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationConfig {
    pub enabled: bool,
    pub reminder_minutes_before: Vec<i64>, // e.g., [15, 10, 5, 2, 1]
    pub show_system_notifications: bool,
    pub play_sound: bool,
}

impl Default for NotificationConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            reminder_minutes_before: vec![15, 10, 5, 2, 1],
            show_system_notifications: true,
            play_sound: true,
        }
    }
}

/// Notification data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrayerNotification {
    pub id: String,
    pub title: String,
    pub body: String,
    pub prayer_name: String,
    pub notification_type: NotificationType,
    pub scheduled_time: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotificationType {
    AdhanReminder,
    IqamaReminder,
    PrayerStart,
}

/// Notification service trait
#[async_trait::async_trait]
pub trait NotificationService: Send + Sync {
    async fn schedule_notification(&self, notification: PrayerNotification) -> anyhow::Result<()>;
    async fn cancel_notification(&self, id: &str) -> anyhow::Result<()>;
    async fn cancel_all_notifications(&self) -> anyhow::Result<()>;
}

/// Simple in-memory notification scheduler
pub struct NotificationScheduler {
    config: NotificationConfig,
}

impl NotificationScheduler {
    pub fn new(config: NotificationConfig) -> Self {
        Self { config }
    }

    pub fn should_notify(&self, minutes_until: i64) -> bool {
        self.config.enabled && self.config.reminder_minutes_before.contains(&minutes_until)
    }
}

use async_trait::async_trait;

#[async_trait]
impl NotificationService for NotificationScheduler {
    async fn schedule_notification(&self, _notification: PrayerNotification) -> anyhow::Result<()> {
        // Implementation would use tauri::api::notification
        // For now, this is a placeholder
        Ok(())
    }

    async fn cancel_notification(&self, _id: &str) -> anyhow::Result<()> {
        Ok(())
    }

    async fn cancel_all_notifications(&self) -> anyhow::Result<()> {
        Ok(())
    }
}
