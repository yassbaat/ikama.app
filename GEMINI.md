# Iqamah - AI Agent Guide (GEMINI.md)

This file provides essential context, instructions, and architectural overviews for AI agents (like Gemini CLI) working on the Iqamah project.

## Project Overview
Iqamah is a cross-platform desktop application (Windows, macOS, Linux) for tracking Islamic prayer times with Mawaqit mosque integration. Its standout features include live iqama countdowns, estimated LIVE prayer status (rak'ah estimation), and travel-time predictions.

- **Primary Stack**: React 18 (Frontend) + Rust (Backend) via **Tauri v1.5**.
- **Data Persistence**: SQLite via `sqlx` (Rust).
- **State Management**: Zustand (TypeScript).
- **Styling**: Tailwind CSS.
- **Data Sources**: Mawaqit Official API, Community Wrapper, and a custom Scraper API.

## Project Structure

### Core Application
- `src/`: React frontend (TypeScript).
  - `components/`: UI components (Cards, Lists, Modals).
  - `hooks/`: Custom hooks (`useStore`, `usePrayerTimes`).
  - `services/`: API and Tauri command wrappers.
  - `types/`: TypeScript type definitions.
- `src-tauri/`: Rust backend.
  - `src/commands/`: IPC handlers for frontend-backend communication.
  - `src/models/`: Data structures (Prayer, Mosque, etc.).
  - `src/services/`: Core business logic (especially `prayer_engine.rs`).
  - `src/providers/`: Data fetching logic from different sources.
  - `src/db/`: SQLite database operations and migrations.

### Supporting Projects
- `Scraped_mawaqit_API/`: A separate Vercel-deployable Node.js/TypeScript API that scrapes Mawaqit data for 150+ countries.
- `lib/`, `android/`, `ios/`, `macos/`, `web/`, `windows/`: Legacy **Flutter** code (preserved for reference but NOT part of the current Tauri build).

## Key Commands

### Development
```bash
# Install all dependencies
npm install

# Run in development mode (Vite + Tauri)
npm run tauri dev

# Run frontend only (no Rust backend)
npm run dev
```

### Testing
```bash
# Frontend tests (Vitest)
npm test

# Rust tests
cd src-tauri && cargo test
```

### Building
```bash
# Create production build for current OS
npm run tauri build
```

## Architectural Principles

### 1. PrayerEngine (The Heart)
The `src-tauri/src/services/prayer_engine.rs` is a pure, stateless Rust module. It handles:
- **Next Prayer**: Identifying the next prayer and time remaining.
- **Rak'ah Estimation**: Calculating the current rak'ah based on iqama time and average durations (2.4 min per rak'ah).
- **Travel Prediction**: Estimating arrival status based on travel time.

### 2. Frontend-Backend Communication
- The frontend calls Rust functions using `invoke('command_name', { args })`.
- These are wrapped in `src/services/tauri.ts` for type safety and ease of use.
- All commands MUST be registered in `src-tauri/src/main.rs`.

### 3. State Management
- Use `src/hooks/useStore.ts` (Zustand) for global app state.
- For prayer-specific timing and countdowns, use the `usePrayerTimes` hook.

### 4. Database
- SQLite is used for caching mosque data, prayer times, and settings.
- Migrations are handled automatically in Rust on startup.

## Development Conventions

### Coding Style
- **Rust**: Follow standard Rust idioms. Use `anyhow` for errors. Max line length 100.
- **TypeScript**: Strict typing. Functional components with hooks. Tailwind for all styling.
- **Clarity over Brevity**: Comment every logical line (except basic HTML/CSS). Use intuitive code.

### UI Guidelines
- Every added DOM element MUST have a unique `id=""`.
- Reuse components or refactor repeated markup into shared components.
- Maintain the "Glassmorphism" aesthetic defined in `src/styles/index.css`.

### Testing Mandate
- **Identify Root Cause**: Before fixing a bug, reproduce it with a test or script.
- **Verification**: Run `npm test` and `cd src-tauri && cargo test` after changes.
- **Browser Testing**: Only use if quicker methods (unit/integration tests) are unavailable.

## Data Providers Flow
The app attempts to fetch data in this priority:
1. **Local Cache**: SQLite database.
2. **Scraper API**: `https://mawaqit-prayer-api.vercel.app` (Primary remote source).
3. **Official API/Scraping**: Fallback logic implemented in Rust providers.

## AI Agent Workflow
1. **Research**: Check `progress.txt` and `to-do-list.md`.
2. **Execute**: Log requests in `progress.txt` and check off tasks in `to-do-list.md`.
3. **Log**: Save every user prompt verbatim to `user_prompts.txt`.
4. **Summarize**: End every response with a one-sentence summary using 🚨🚨🚨.

🚨🚨🚨 Generated comprehensive GEMINI.md context file covering project architecture, tech stack, and development standards.
