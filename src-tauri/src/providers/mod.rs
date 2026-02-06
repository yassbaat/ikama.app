pub mod prayer_data_provider;
pub mod official_api_provider;
pub mod community_wrapper_provider;
pub mod scraping_provider;
pub mod fallback_provider;
pub mod mawaqit_provider;

pub use prayer_data_provider::*;
pub use official_api_provider::*;
pub use community_wrapper_provider::*;
pub use scraping_provider::*;
#[allow(unused_imports)]
pub use fallback_provider::*;
pub use mawaqit_provider::*;
