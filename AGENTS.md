# Iqamah - AI Coding Agent Reference

## Project Overview

Iqamah is a cross-platform desktop application for tracking Islamic prayer times with Mawaqit mosque integration. It provides live countdowns to prayer iqama times, an "estimated LIVE prayer status" feature (rakʿah estimation), and travel-time calculations to help users determine when to leave for the mosque.

**Primary Language:** English (code and documentation)

### Key Information
- **Name:** Iqamah
- **Version:** 1.0.0
- **License:** MIT
- **Target Platforms:** Windows, macOS, Linux
- **Bundle Identifier:** com.iqamah.app
- **Window Size:** 1200x800 (min: 800x600)

---

## Technology Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 18 + TypeScript |
| Build Tool | Vite 5 |
| State Management | Zustand 4 |
| Styling | Tailwind CSS 3 |
| UI Icons | Lucide React |
| Date Utilities | date-fns |
| Backend | Rust |
| Desktop Framework | Tauri v1.5 |
| Database | SQLite (via sqlx) |
| HTTP Client | reqwest (Rust), fetch (JS) |
| Notifications | Tauri native |

### Key Dependencies

**Frontend (package.json):**
- `react`, `react-dom` - UI framework
- `react-router-dom` - Navigation
- `zustand` - State management
- `date-fns` - Date utilities
- `lucide-react` - Icons
- `tailwindcss` - Styling
- `clsx`, `tailwind-merge` - Class utilities
- `@tauri-apps/api` - Tauri bindings

**Backend (Cargo.toml):**
- `tauri` - Desktop framework with notifications, filesystem, window controls
- `tokio` - Async runtime
- `sqlx` - Database ORM with SQLite
- `reqwest` - HTTP client
- `scraper` - HTML parsing
- `chrono` - Date/time handling
- `serde`, `serde_json` - Serialization
- `thiserror`, `anyhow` - Error handling
- `dirs` - Platform-appropriate directories

---

## Project Structure

```
iqamah.com/
├── src/                          # React Frontend
│   ├── components/               # UI Components
│   │   ├── App.tsx              # Main app component
│   │   ├── ErrorDisplay.tsx     # Error message display
│   │   ├── Header.tsx           # App header with branding
│   │   ├── LiveTimer.tsx        # Live countdown timer
│   │   ├── MosqueSelector.tsx   # Mosque search/selection
│   │   ├── NextPrayerCard.tsx   # Main countdown display
│   │   ├── NightPrayerCard.tsx  # Tahajjud/Qiyam calculator
│   │   ├── PrayerList.tsx       # Daily prayer list display
│   │   ├── SettingsModal.tsx    # Settings dialog
│   │   └── TravelTimeCard.tsx   # Travel time feature
│   ├── hooks/                    # Custom React hooks
│   │   ├── useStore.ts          # Zustand store
│   │   ├── usePrayerTimes.ts    # Prayer time logic with countdown
│   │   ├── useLiveTimer.ts      # Timer hooks
│   │   └── __tests__/           # Hook tests
│   ├── services/                 # Frontend services
│   │   ├── mawaqitApi.ts        # Mawaqit scraper API client
│   │   ├── nightPrayer.ts       # Night prayer calculations
│   │   ├── tauri.ts             # Tauri command wrappers
│   │   ├── time.ts              # Time utilities
│   │   └── __tests__/           # Service tests
│   ├── types/                    # TypeScript definitions
│   │   └── index.ts             # All type definitions
│   └── styles/
│       └── index.css            # Tailwind + custom styles
│
├── src-tauri/                    # Rust Backend
│   ├── src/
│   │   ├── main.rs              # App entry point
│   │   ├── lib.rs               # Library exports
│   │   ├── commands/            # Tauri IPC handlers
│   │   │   ├── mod.rs
│   │   │   ├── mosque_commands.rs
│   │   │   ├── prayer_commands.rs
│   │   │   └── settings_commands.rs
│   │   ├── models/              # Data models
│   │   │   ├── mod.rs
│   │   │   ├── prayer.rs        # Prayer, PrayerTimes, RakahEstimate
│   │   │   ├── mosque.rs        # Mosque, MosqueSearchResult
│   │   │   ├── geo_location.rs
│   │   │   └── provider.rs
│   │   ├── services/            # Business logic
│   │   │   ├── mod.rs
│   │   │   ├── prayer_engine.rs # Core calculation engine
│   │   │   ├── notification_service.rs
│   │   │   └── location_service.rs
│   │   ├── providers/           # Data providers
│   │   │   ├── mod.rs
│   │   │   ├── prayer_data_provider.rs  # Trait definition
│   │   │   ├── official_api_provider.rs
│   │   │   ├── community_wrapper_provider.rs
│   │   │   ├── scraping_provider.rs
│   │   │   ├── fallback_provider.rs
│   │   │   └── mawaqit_provider.rs
│   │   └── db/                  # Database layer
│   │       ├── mod.rs
│   │       ├── database.rs      # Database operations
│   │       └── migrations.rs    # Schema migrations
│   ├── Cargo.toml
│   ├── tauri.conf.json          # Tauri configuration
│   └── build.rs
│
├── lib/                          # Legacy Flutter code (preserved)
├── android/, ios/, macos/, web/, windows/  # Legacy platform folders
├── .github/workflows/release.yml # CI/CD pipeline
├── docs/                         # GitHub Pages files
├── package.json
├── vite.config.ts
├── vitest.config.ts
├── tailwind.config.js
└── tsconfig.json
```

---

## Build Commands

### Prerequisites
- Node.js 18+
- Rust (latest stable)
- Platform-specific build tools:
  - Windows: Visual Studio 2022 with C++ build tools
  - macOS: Xcode
  - Linux: build-essential, libgtk-3-dev, libwebkit2gtk-4.0-dev

### Development
```bash
# Install dependencies
npm install

# Run development server (starts Vite + Tauri)
npm run tauri dev

# Run frontend only
npm run dev
```

### Testing
```bash
# Frontend tests (Vitest)
npm test
npm run test:run      # CI mode
npm run test:ui       # UI mode

# Rust tests
cd src-tauri && cargo test
cd src-tauri && cargo test -- --nocolor  # No ANSI colors
```

### Building
```bash
# Production build for current platform
npm run tauri build

# Platform-specific builds
npm run tauri build -- --target x86_64-pc-windows-msvc
npm run tauri build -- --target x86_64-apple-darwin      # macOS Intel
npm run tauri build -- --target aarch64-apple-darwin     # macOS Apple Silicon
npm run tauri build -- --target x86_64-unknown-linux-gnu # Linux
```

### Release
```bash
# Method 1: Automated (GitHub Actions) - RECOMMENDED
git tag v1.0.0
git push origin v1.0.0

# Method 2: Local PowerShell script
npm run tauri build
./release.ps1
```

---

## Code Style Guidelines

### Rust
- Follow official [Rust Style Guide](https://doc.rust-lang.org/style/)
- Run `cargo fmt` before committing
- Run `cargo clippy` for linting
- Max line length: 100 characters
- Use `snake_case` for files, functions, variables
- Use `PascalCase` for types, structs, enums
- Error handling: `anyhow` for app code, `thiserror` for errors
- Prefer `Result` over panics

### TypeScript/React
- Strict TypeScript mode enabled
- Functional components with hooks
- Use `camelCase` for functions/variables
- Use `PascalCase` for types/components
- Tailwind CSS for all styling
- Prefer `const` over `let`

---

## Testing Strategy

### Unit Tests

**Rust (Priority):**
- `prayer_engine.rs` - All calculation methods have comprehensive tests
- Tests cover: next prayer detection, rakah estimation, travel predictions
- Run with: `cd src-tauri && cargo test`

**TypeScript:**
- Hook tests in `src/hooks/__tests__/`
- Service tests in `src/services/__tests__/`
- Uses Vitest + jsdom + Testing Library

### Test Files
- Rust: Inline `#[cfg(test)]` modules
- TS: `*.test.ts` alongside source files

---

## Architecture Details

### PrayerEngine (Core Logic)

The `PrayerEngine` is a pure, stateless Rust module containing all calculation logic.

**Configuration Defaults:**
- `rakah_duration_seconds` = 144 (2.4 minutes per rakah)
- `start_lag_seconds` = 0-120 (imam start delay)
- `buffer_before_start_seconds` = 30 (arrive early buffer)
- `post_prayer_display_minutes` = 28 (show "ended X min ago")
- `catch_up_minutes` = 3 (window to still catch prayer)
- Default rakah counts: Fajr=2, Dhuhr=4, Asr=4, Maghrib=3, Isha=4

**Key Methods:**
- `get_next_prayer(schedule, now)` - Find next prayer
- `estimate_rakah(prayer, now)` - Estimate current rakah
- `calculate_travel_prediction(prayer, travel_time, now)` - Travel calculations
- `get_countdown(prayer, now)` - Time until iqama
- `format_duration(seconds)` - Human-readable duration

### Data Providers

Three provider implementations behind `PrayerDataProvider` trait:

1. **Official API Provider** - Token-based Mawaqit API
2. **Community Wrapper Provider** - REST API wrapper (Vercel)
3. **Scraping Provider** - HTML fallback with rate limiting
4. **Fallback Provider** - Chains providers with fallback logic

**Current Implementation:** The frontend primarily uses the Mawaqit scraper API at `https://mawaqit-prayer-api.vercel.app` directly via the `mawaqitApi.ts` service.

### State Management (Zustand)

Key state slices:
- `currentMosque` / `currentPrayerTimes` - Selected mosque data
- `nextPrayer` / `countdowns` - Prayer timing state
- `rakahEstimate` - Live estimation state
- `favoriteMosques` - User favorites
- `settings` - App preferences
- `isLoading` / `error` - UI state

---

## Security Considerations

### Data Storage
- API tokens: Not currently used (public scraper API)
- User preferences: SQLite in app data directory
- Database path: 
  - Windows: `%APPDATA%/iqamah/iqamah.db`
  - macOS: `~/Library/Application Support/iqamah/iqamah.db`
  - Linux: `~/.local/share/iqamah/iqamah.db`

### Network
- HTTPS enforced for all API calls
- No sensitive data transmitted
- Mosque searches via public API

### Privacy
- Location: Optional, only used for mosque search
- No analytics or tracking
- All data stored locally

---

## Deployment

### GitHub Actions CI/CD

File: `.github/workflows/release.yml`

Triggers on tag push (`v*`):
- Builds for Windows (NSIS installer + MSI)
- Builds for macOS (DMG)
- Builds for Linux (DEB + AppImage)
- Creates GitHub release with all artifacts

### Output Locations
- Windows: `src-tauri/target/release/bundle/nsis/*.exe`, `msi/*.msi`
- macOS: `src-tauri/target/release/bundle/dmg/*.dmg`
- Linux: `src-tauri/target/release/bundle/deb/*.deb`, `appimage/*.AppImage`

---

## Migration from Flutter

This project was migrated from Flutter to Tauri. Key mappings:

| Flutter | Tauri |
|---------|-------|
| `lib/domain/services/prayer_engine.dart` | `src-tauri/src/services/prayer_engine.rs` |
| `lib/domain/entities/*.dart` | `src-tauri/src/models/*.rs` |
| `lib/data/providers/*.dart` | `src-tauri/src/providers/*.rs` |
| `lib/presentation/screens/*.dart` | `src/components/*.tsx` |
| `lib/presentation/blocs/*.dart` | `src/hooks/useStore.ts` |
| `sqflite` | `sqlx` |
| `dio` | `reqwest` |
| `BLoC` | `Zustand` |

Legacy Flutter code is preserved in `/lib` for reference.

---

## Useful Commands Reference

```bash
# Development
npm run dev              # Vite dev server only
npm run tauri dev        # Full Tauri dev mode

# Testing
npm test                 # Vitest
npm run test:run         # CI mode
npm run test:ui          # UI mode
cd src-tauri && cargo test

# Building
npm run build            # Vite production build
npm run tauri build      # Full production build

# Code quality
cargo fmt                # Format Rust
cargo clippy             # Lint Rust
npx tsc --noEmit         # TypeScript check
```

---

## File Checklist for New Features

When adding a new feature:
- [ ] Rust models in `src-tauri/src/models/`
- [ ] Commands in `src-tauri/src/commands/`
- [ ] Business logic in `src-tauri/src/services/`
- [ ] Database operations in `src-tauri/src/db/`
- [ ] React components in `src/components/`
- [ ] State updates in `src/hooks/useStore.ts`
- [ ] Types in `src/types/index.ts`
- [ ] Rust tests for calculations
- [ ] TypeScript tests for hooks
- [ ] Register command in `main.rs` invoke_handler

---

## Notes for AI Agents

1. **Database:** Uses SQLite with sqlx. Migrations run automatically on startup in `main.rs`.
2. **Error Handling:** Rust uses `anyhow::Result`, TypeScript uses try/catch with error state.
3. **Time Handling:** All times are UTC internally, converted for display.
4. **API Calls:** Frontend can call external APIs directly OR via Tauri commands.
5. **State Updates:** Use Zustand store actions, never mutate state directly.
6. **Async:** Prefer async/await over callbacks in both Rust and TypeScript.
7. **Testing:** Add tests for calculation logic in Rust, UI logic in TypeScript.
8. **Tauri Commands:** All commands are registered in `main.rs` invoke_handler and wrapped in `src/services/tauri.ts`.
