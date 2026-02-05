# Iqamah

Cross-platform prayer times app with Mawaqit integration, live countdowns, and estimated LIVE prayer status (rak'ah estimation).

> **⚠️ MIGRATED**: This project has been migrated from Flutter to Tauri (Rust + React) for better performance and native desktop experience.

## Features

- 🕌 **Mosque Selection**: Search mosques by name/city or find nearby mosques
- ⏰ **Live Countdown**: Real-time countdown to next adhan and iqama
- 📿 **LIVE Rak'ah Estimation**: Estimate which rak'ah the congregation is in
- 🚗 **Travel Time**: Calculate when to leave and which rak'ah you'll catch
- 💻 **Multi-Platform**: Windows, macOS, Linux
- 🔔 **Notifications**: System notifications for prayer times
- 💾 **Offline Mode**: Local SQLite caching for offline access
- 🔄 **Multiple Data Sources**: Official API, Community Wrapper, HTML Scraping fallback

## New Tech Stack (Tauri)

| Component | Technology |
|-----------|------------|
| Frontend | React 18 + TypeScript |
| Styling | Tailwind CSS |
| State | Zustand |
| Backend | Rust |
| Framework | Tauri |
| Database | SQLite |

## Quick Start

### Prerequisites

- [Node.js](https://nodejs.org/) 18+
- [Rust](https://rustup.rs/) latest stable

### Installation

```bash
# Clone the repository
git clone <repo-url>
cd iqamah

# Install dependencies
npm install

# Run development server
npm run tauri dev

# Build for production
npm run tauri build
```

## Architecture

```
┌──────────────────────────────────────────┐
│           React Frontend                  │
│  ┌─────────────┐    ┌─────────────────┐  │
│  │  Components │    │   Hooks/Store   │  │
│  │  - Cards    │◄──►│   (Zustand)     │  │
│  │  - Lists    │    └─────────────────┘  │
│  │  - Forms    │                          │
│  └─────────────┘                          │
└─────────────────┬────────────────────────┘
                  │ Tauri Commands
                  ▼
┌──────────────────────────────────────────┐
│            Rust Backend                   │
│  ┌─────────────┐    ┌─────────────────┐  │
│  │  Commands   │    │  PrayerEngine   │  │
│  │  ├ Mosques  │◄──►│  (Calculations) │  │
│  │  ├ Prayers  │    └─────────────────┘  │
│  │  └ Settings │                          │
│  └─────────────┘    ┌─────────────────┐  │
│                     │  Data Providers │  │
│  ┌─────────────┐    │  ├ Official API │  │
│  │  Database   │◄──►│  ├ Community    │  │
│  │  (SQLite)   │    │  └ Scraping     │  │
│  └─────────────┘    └─────────────────┘  │
└──────────────────────────────────────────┘
```

## Data Providers

The app supports 3 data provider implementations behind a unified interface:

1. **Provider A - Official API**: Direct Mawaqit API access (requires token)
2. **Provider B - Community Wrapper**: REST API wrapper (recommended)
3. **Provider C - HTML Scraping**: HTML scraping fallback

## PrayerEngine

The core calculation engine is implemented in Rust:

```rust
let engine = PrayerEngine::with_defaults();

// Get next prayer
let next = engine.get_next_prayer(&schedule, now);

// Estimate rakah
let estimate = engine.estimate_rakah(&prayer, now);

// Travel prediction
let prediction = engine.calculate_travel_prediction(&prayer, travel_time, now);
```

## Project Structure

```
├── src/                    # React frontend
│   ├── components/         # UI components
│   ├── hooks/              # Custom hooks
│   ├── services/           # Tauri API wrappers
│   ├── types/              # TypeScript types
│   └── styles/             # Tailwind CSS
│
├── src-tauri/              # Rust backend
│   ├── src/
│   │   ├── commands/       # Tauri commands
│   │   ├── models/         # Data models
│   │   ├── services/       # Business logic
│   │   ├── providers/      # Data providers
│   │   └── db/             # Database layer
│   └── Cargo.toml
│
└── package.json
```

## Migration Notes

This project was originally built with Flutter. The migration to Tauri provides:

- **Smaller bundle size** (~5MB vs ~50MB+)
- **Better native integration** (system tray, notifications)
- **Improved performance** (Rust backend)
- **Faster development** (hot reload for both frontend and backend)

## Legacy Flutter Code

The original Flutter code is preserved in the `flutter_legacy/` branch for reference.

## License

[To be determined]

## Acknowledgments

- Prayer times data from Mawaqit
- Built with Tauri + React + Rust
