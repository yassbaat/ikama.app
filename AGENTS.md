# Iqamah.com Project (Tauri Version)

## Project Overview

Iqamah is a cross-platform desktop application that integrates with Mawaqit mosque prayer times. The app provides live countdowns to prayer iqama times, an "estimated LIVE prayer status" feature (rakʿah estimation), and travel-time ETA calculations to help users determine when to leave and which rakʿah they will catch.

**Target Platforms:** Windows, macOS, Linux  
**Tech Stack:** Tauri (Rust + React/TypeScript) with SQLite

## Migration from Flutter

This project was migrated from Flutter to Tauri for improved performance, smaller bundle size, and better native desktop integration. The Flutter code is preserved in a separate branch for reference.

### Key Changes
- **Frontend**: Flutter/Dart → React/TypeScript with Tailwind CSS
- **State Management**: BLoC → Zustand
- **Backend**: Dart → Rust
- **Database**: sqflite → sqlx (SQLite)
- **HTTP Client**: Dio → reqwest
- **Notifications**: flutter_local_notifications → tauri-plugin-notification

## Core Features

### A) Mosque Selection & Data
- Search mosques by name/city
- "Nearest mosques" using geolocation (optional)
- Save multiple favorites with one "active" mosque
- Display daily prayers: Fajr, Dhuhr, Asr, Maghrib, Isha (+ Jumu'ah if present)
- Show adhan time and iqama time for each prayer
- Local SQLite caching for offline mode
- Automatic refresh: once per day after midnight, on app open, and manual refresh

### B) Countdown UX
- Main widget showing "Next prayer" with prayer name, time until adhan, time until iqama, and countdown timer
- Secondary list view of all prayers for today
- System tray integration with quick view
- Configurable notification schedule: T-15min, T-10, T-5, T-2, T-1, T-0

### C) LIVE Prayer Estimation (Rakʿah Progress)
Estimates which rakʿah the congregation is in after iqama starts.

**Configuration Defaults:**
- `rakahDurationSeconds` = 144 (2.4 minutes), user-configurable
- `startLagSeconds` = 0-120 (imam start delay fudge)
- `bufferBeforeStartSeconds` = 30 (arrive early buffer)
- Default rakʿah counts: Fajr=2, Dhuhr=4, Asr=4, Maghrib=3, Isha=4, Jumu'ah=2

**Algorithm:**
1. `prayerStart = iqamaTime + startLagSeconds`
2. If now < prayerStart: status = "Not started" + countdown
3. If now >= prayerStart:
   - `elapsed = now - prayerStart`
   - `rakahIndex = floor(elapsed / rakahDurationSeconds) + 1` (clamped to [1..rakahCount])
   - `prayerEstimatedEnd = prayerStart + (rakahCount * rakahDurationSeconds)`
4. UI displays: "LIVE (estimated)" badge, "Prayer started X min ago (est.)", "Rakʿah N / total", progress bar

### D) Travel Time Feature
Calculates "what rakʿah will I catch?" and "when should I leave?"

**User Inputs:**
- `travelTimeSeconds` (per mosque, optionally per transport mode)
- `targetArrivalRule`: arrive before prayerStart (default) or before rakʿah K

**Calculations:**
- `desiredArrivalTime = prayerStart - bufferBeforeStartSeconds`
- `recommendedLeaveTime = desiredArrivalTime - travelTimeSeconds`
- Arrival rakʿah prediction based on travel time + prayer start

### E) Data Provider Architecture
Three provider implementations behind a unified `PrayerDataProvider` interface:

1. **Provider A (Official/Private API):** Token-based auth with configurable base URL and endpoints
2. **Provider B (Community Wrapper):** User-supplied base URL + optional API key for REST wrapper
3. **Provider C (HTML Scraping):** Fallback with opt-in, robust parsing, caching, and rate limiting

## Project Architecture

```
src/                        # React frontend
├── components/             # UI components
│   ├── NextPrayerCard.tsx
│   ├── PrayerList.tsx
│   ├── TravelTimeCard.tsx
│   ├── MosqueSelector.tsx
│   ├── SettingsModal.tsx
│   └── Header.tsx
├── hooks/                  # Custom React hooks
│   ├── useStore.ts        # Zustand store
│   └── usePrayerTimes.ts  # Prayer time logic
├── services/               # Frontend services
│   ├── tauri.ts          # Tauri command wrappers
│   └── time.ts           # Time formatting
├── types/                  # TypeScript types
│   └── index.ts
└── styles/
    └── index.css          # Tailwind styles

src-tauri/                  # Rust backend
├── src/
│   ├── commands/          # Tauri commands (IPC handlers)
│   │   ├── mosque_commands.rs
│   │   ├── prayer_commands.rs
│   │   ├── provider_commands.rs
│   │   └── settings_commands.rs
│   ├── models/            # Data models
│   │   ├── prayer.rs      # Prayer, PrayerTimes, RakahEstimate
│   │   ├── mosque.rs      # Mosque, MosqueSearchResult
│   │   ├── geo_location.rs # GeoLocation
│   │   └── provider.rs    # ProviderInfo, ConfigField
│   ├── services/          # Business logic
│   │   ├── prayer_engine.rs  # Core calculation engine
│   │   ├── notification_service.rs
│   │   └── location_service.rs
│   ├── providers/         # Data providers
│   │   ├── prayer_data_provider.rs  # Trait definition
│   │   ├── official_api_provider.rs
│   │   ├── community_wrapper_provider.rs
│   │   ├── scraping_provider.rs
│   │   └── fallback_provider.rs
│   └── db/                # Database layer
│       ├── database.rs    # Database operations
│       └── migrations.rs  # Schema migrations
└── Cargo.toml
```

## Data Models

### Prayer (Rust)
```rust
struct Prayer {
    name: String,
    adhan: DateTime<Utc>,
    iqama: Option<DateTime<Utc>>,
    custom_rakah_count: Option<i32>,
}
```

### PrayerTimes (Rust)
```rust
struct PrayerTimes {
    date: DateTime<Utc>,
    fajr: Prayer,
    dhuhr: Prayer,
    asr: Prayer,
    maghrib: Prayer,
    isha: Prayer,
    jumuah: Option<Prayer>,
    mosque_id: Option<String>,
    cached_at: Option<DateTime<Utc>>,
}
```

### PrayerEngine Module

The `PrayerEngine` is a pure, stateless Rust module containing all calculation logic.

**Key Methods:**
- `get_next_prayer(schedule, now) -> NextPrayerResult`
- `estimate_rakah(prayer, now) -> RakahEstimate`
- `calculate_travel_prediction(prayer, travel_time, now) -> TravelPrediction`
- `get_countdown(prayer, now) -> Duration`

## Build Commands

### Prerequisites
- Node.js 18+
- Rust latest stable
- Platform build tools (VS2022/Xcode/build-essential)

### Development
```bash
# Install dependencies
npm install

# Run development server
npm run tauri dev

# Run tests
# Rust tests
cd src-tauri && cargo test

# Build for production
npm run tauri build
```

### Building for Release

```bash
# Windows
npm run tauri build -- --target x86_64-pc-windows-msvc

# macOS Intel
npm run tauri build -- --target x86_64-apple-darwin

# macOS Apple Silicon  
npm run tauri build -- --target aarch64-apple-darwin

# Linux
npm run tauri build -- --target x86_64-unknown-linux-gnu
```

## Code Style Guidelines

### Rust Conventions
- Follow the official [Rust Style Guide](https://doc.rust-lang.org/style/)
- Use `cargo fmt` for formatting
- Use `cargo clippy` for linting
- Max line length: 100 characters
- Error handling: Use `anyhow` for application code, `thiserror` for libraries

### TypeScript/React Conventions
- Use TypeScript strict mode
- Functional components with hooks
- Tailwind CSS for styling
- Zustand for state management

### Naming Conventions
- Rust: `snake_case` for files/functions/variables, `PascalCase` for types/structs
- TypeScript: `camelCase` for functions/variables, `PascalCase` for types/components

## Testing Strategy

### Unit Tests (Priority)
- **PrayerEngine:** All calculation methods in `src-tauri/src/services/prayer_engine.rs`
- **Providers:** Mock HTTP responses, parsing logic
- **Models:** Serialization/deserialization

### Run Tests
```bash
# Rust tests
cd src-tauri && cargo test

# Watch mode
cd src-tauri && cargo watch -x test
```

## Security Considerations

### Data Storage
- **API Tokens:** Stored securely using Tauri's secure storage
- **User Preferences:** SQLite database in app data directory
- **Cached Prayer Times:** SQLite with appropriate expiration

### Network Security
- Use HTTPS for all API calls
- Certificate pinning for production (optional)
- Rate limiting for scraping provider (max 1 request per minute)

### Privacy
- Location data: Only accessed when needed, never stored remotely
- Mosque search queries: Not logged or sent to analytics
- User settings: Stored locally only

## System Tray

The app integrates with the system tray for quick access:
- Left click: Show/hide app window
- Menu items: Show app, Quit

## Error Handling

The app uses a comprehensive error handling strategy:
1. Rust errors are mapped to user-friendly messages
2. Network errors trigger fallback to cached data
3. All errors are logged for debugging

## Configuration Files

### package.json
Key dependencies:
- `react` / `react-dom` - UI framework
- `zustand` - State management
- `tailwindcss` - Styling
- `@tauri-apps/api` - Tauri bindings

### Cargo.toml
Key dependencies:
- `tauri` - Desktop framework
- `tokio` - Async runtime
- `sqlx` - Database
- `reqwest` - HTTP client
- `scraper` - HTML parsing

## License

[To be determined - specify project license here]

## Contributing

All PRs should:
1. Pass all Rust tests (`cargo test`)
2. Pass TypeScript type checking (`tsc --noEmit`)
3. Follow the code style guidelines
4. Include tests for new features
