use serde::{Deserialize, Serialize};

/// Configuration field types
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConfigFieldType {
    String,
    Password,
    Number,
    Boolean,
    Url,
    Select,
}

/// Configuration schema field for provider settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfigField {
    pub key: String,
    pub label: String,
    pub field_type: ConfigFieldType,
    #[serde(default)]
    pub required: bool,
    pub description: Option<String>,
    pub default_value: Option<String>,
    pub options: Option<Vec<String>>,
}

impl ConfigField {
    pub fn new(key: impl Into<String>, label: impl Into<String>, field_type: ConfigFieldType) -> Self {
        Self {
            key: key.into(),
            label: label.into(),
            field_type,
            required: false,
            description: None,
            default_value: None,
            options: None,
        }
    }

    pub fn required(mut self) -> Self {
        self.required = true;
        self
    }

    pub fn description(mut self, desc: impl Into<String>) -> Self {
        self.description = Some(desc.into());
        self
    }

    pub fn default_value(mut self, value: impl Into<String>) -> Self {
        self.default_value = Some(value.into());
        self
    }

    pub fn options(mut self, opts: Vec<String>) -> Self {
        self.options = Some(opts);
        self
    }
}

/// Provider metadata
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderInfo {
    pub id: String,
    pub name: String,
    pub description: String,
    pub config_schema: Vec<ConfigField>,
}

/// Provider configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderConfig {
    pub provider_id: String,
    pub settings: serde_json::Value,
}

/// Provider test result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProviderTestResult {
    pub success: bool,
    pub message: String,
    pub latency_ms: Option<u64>,
}

/// Available provider types
pub const PROVIDER_OFFICIAL_API: &str = "official_api";
pub const PROVIDER_COMMUNITY_WRAPPER: &str = "community_wrapper";
pub const PROVIDER_SCRAPING: &str = "scraping";
