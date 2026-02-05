# Iqamah - Tauri Migration

Cross-platform prayer times app migrated from Flutter to Tauri (Rust + React).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        FRONTEND (React)                         │
├─────────────────────────────────────────────────────────────────┤
│  Components        Hooks         Services        Types          │
│  ───────────       ─────         ─────────       ─────          │
│  NextPrayerCard    useStore      tauri.ts        Prayer         │
│  PrayerList        usePrayerTimes time.ts        Mosque         │
│  TravelTimeCard                                 PrayerTimes     │
│  MosqueSelector                                  NextPrayer...  │
│  SettingsModal                                   etc.           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Tauri Commands
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND (Rust)                             │
├─────────────────────────────────────────────────────────────────┤
│  Commands          Services       Providers      Database       │
│  ─────────         ─────────      ──────────     ─────────      │
│  mosque_commands   PrayerEngine   Official API   SQLite         │
│  prayer_commands   Notifications  Community API  Settings       │
│  provider_commands Location       Scraping       Cache          │
│  settings_commands                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend Framework | React 18 + TypeScript |
| Styling | Tailwind CSS |
| State Management | Zustand |
| Icons | Lucide React |
| Backend | Rust |
| Desktop Framework | Tauri v1.5 |
| Database | SQLite (sqlx) |
| HTTP Client | reqwest |
| HTML Scraping | scraper |

## Features

- ✅ **Mosque Selection**: Search and save favorite mosques
- ✅ **Live Countdown**: Real-time countdown to next adhan and iqama
- ✅ **LIVE Rak'ah Estimation**: Estimate which rak'ah the congregation is in
- ✅ **Travel Time Calculator**: Calculate when to leave and which rak'ah you'll catch
- ✅ **Multi-Platform**: Windows, macOS, Linux (via Tauri)
- ✅ **Offline Mode**: SQLite caching for offline access
- ✅ **System Tray**: Quick access from system tray
- ✅ **Multiple Data Providers**: Official API, Community Wrapper, HTML Scraping

## Project Structure

```
├── src/                          # React frontend
│   ├── components/               # React components
│   │   ├── NextPrayerCard.tsx
│   │   ├── PrayerList.tsx
│   │   ├── TravelTimeCard.tsx
│   │   ├── MosqueSelector.tsx
│   │   ├── SettingsModal.tsx
│   │   └── Header.tsx
│   ├── hooks/                    # Custom React hooks
│   │   ├── useStore.ts          # Zustand store
│   │   └── usePrayerTimes.ts    # Prayer time hooks
│   ├── services/                 # Frontend services
│   │   ├── tauri.ts             # Tauri command wrappers
│   │   └── time.ts              # Time formatting utilities
│   ├── types/                    # TypeScript types
│   │   └── index.ts
│   ├── styles/                   # CSS styles
│   │   └── index.css
│   ├── App.tsx
│   └── main.tsx
│
├── src-tauri/                    # Rust backend
│   ├── src/
│   │   ├── main.rs              # Entry point
│   │   ├── commands/            # Tauri commands
│   │   │   ├── mosque_commands.rs
│   │   │   ├── prayer_commands.rs
│   │   │   ├── provider_commands.rs
│   │   │   └── settings_commands.rs
│   │   ├── models/              # Data models
│   │   │   ├── prayer.rs
│   │   │   ├── mosque.rs
│   │   │   ├── geo_location.rs
│   │   │   └── provider.rs
│   │   ├── services/            # Business logic
│   │   │   ├── prayer_engine.rs # Core calculation engine
│   │   │   ├── notification_service.rs
│   │   │   └── location_service.rs
│   │   ├── providers/           # Data providers
│   │   │   ├── prayer_data_provider.rs
│   │   │   ├── official_api_provider.rs
│   │   │   ├── community_wrapper_provider.rs
│   │   │   ├── scraping_provider.rs
│   │   │   └── fallback_provider.rs
│   │   └── db/                  # Database layer
│   │       ├── database.rs
│   │       └── migrations.rs
│   ├── Cargo.toml
│   └── tauri.conf.json
│
├── package.json
├── tailwind.config.js
├── vite.config.ts
└── tsconfig.json
```

## Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [Rust](https://rustup.rs/) latest stable
- Platform-specific build tools:
  - **Windows**: Visual Studio 2022 Build Tools
  - **macOS**: Xcode command line tools
  - **Linux**: `build-essential`, `libgtk-3-dev`, `libwebkit2gtk-4.0-dev`

## Development

```bash
# Install dependencies
npm install

# Run development server
npm run tauri dev

# Build for production
npm run tauri build
```

## Building for Different Platforms

```bash
# Windows
npm run tauri build -- --target x86_64-pc-windows-msvc

# macOS
npm run tauri build -- --target x86_64-apple-darwin
npm run tauri build -- --target aarch64-apple-darwin  # Apple Silicon

# Linux
npm run tauri build -- --target x86_64-unknown-linux-gnu
```

## Data Providers

The app supports 3 data provider implementations:

1. **Provider A - Official API**: Direct Mawaqit API access (requires token)
2. **Provider B - Community Wrapper**: REST API wrapper (recommended)
3. **Provider C - Web Scraping**: HTML scraping fallback

## PrayerEngine Algorithm

The Rust PrayerEngine provides pure, stateless calculation logic:

```rust
// Get next prayer
let result = engine.get_next_prayer(&schedule, now);

// Estimate current rakah
let estimate = engine.estimate_rakah(&prayer, now);

// Calculate travel prediction
let prediction = engine.calculate_travel_prediction(&prayer, travel_time, now);
```

## Migration from Flutter

| Flutter | Tauri |
|---------|-------|
| Dart/Flutter | Rust + React |
| BLoC Pattern | Zustand |
| sqflite | sqlx (SQLite) |
| Dio | reqwest |
| flutter_local_notifications | tauri-plugin-notification |
| geolocator | Native platform APIs |

## License

[To be determined]
