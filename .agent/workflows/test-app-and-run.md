---
description: Universal Application Verification & Diagnostic Workflow
---
# /test-app-and-run
Universal Verify + Diagnose (Post-Change)

## 🎯 MISSION
After any change, this workflow ensures the application is healthy end-to-end. It diagnoses failures automatically using logs, console output, and network traffic, applying safe auto-fixes before producing a concrete report. **Trust the automation, not the "open and see" method.**

## 🛠 DEBUG ACCELERATION & FEASIBILITY (USER TIPS)
To help me solve complex problems faster, use these strategy-based prompts:

- **"Verify Feasibility First"**: Before building, ask me to **"Search the web for API limits, site changes, or maintenance status"**. This prevents building on broken or private infrastructure.
- **"Audit Runtime Logs Immediately"**: Don't guess. Ask me to **"Fetch logs from the deployment provider (Vercel/Docker/AWS) or local runtime"**.
- **"Inspect Raw Source Data"**: If logic fails, tell me to **"Log the raw input/response before parsing"** to catch format shifts like `let` vs `var` or bot-protection hurdles.
- **"Isolate Logic with a Test Script"**: Tell me to **"Write a standalone scratch script (e.g., test-logic.ts)"** to verify a single function in isolation.
- **"Local-Prod Delta Check"**: If a bug only happens in production, mention it explicitly to focus me on Environment Variables and Infrastructure.

## 📋 GLOBAL RULES
1. **Never open the browser as "the test"**. The browser is for evidence collection and final validation only.
2. **Collect Evidence First**: On failure, gather logs/screenshots before suggesting fixes.
3. **Safe Auto-Fixes Only**: Only apply mechanical fixes (lint --fix, format, cache clear, missing imports). Never make speculative logic changes.
4. **Fast Fail**: If Stage 1 or 2 fails, stop immediately to save time.

## 🚀 WORKFLOW STAGES

### STAGE 0 — PROJECT DETECTION
- Detect package manager (pnpm, yarn, npm) via lockfile.
- Inventory scripts: `lint`, `typecheck`, `test`, `build`, `dev`, `preview`.

### STAGE 1 — PREFLIGHT & DEPENDENCIES
- Verify `node -v`.
- Install dependencies (using `--frozen-lockfile` where applicable).
- **Auto-Fix**: If install fails due to lock mismatch, retry a standard install once.

### STAGE 2 — STATIC CHECKS (FAST FAIL)
- **Lint**: Run `<pm> run lint`. If `autoFix=true`, run `lint:fix` or `format`.
- **Typecheck**: Run `<pm> run typecheck` or `tsc --noEmit`. No speculative fixes allowed here.

### STAGE 3 — SUITE VALIDATION (TESTS)
- Run unit/integration tests (`<pm> run test`).
- On failure: Report failing suites. Do not guess logic fixes.

### STAGE 4 — PRODUCTION BUILD
- Run `<pm> run build`.
- **Auto-Fix**: If it fails, clear caches (`.vite`, `dist`, `.next`) and retry once.

### STAGE 5 — RUNTIME SMOKE TEST (APP RENDERS)
- **Start Server**: Launch `dev` or `preview` in a background session.
- **Port Handling**: If port is in use, increment and retry up to 10 times.
- **HTTP Healthcheck**: Curl specified `healthPaths` if provided.
- **Browser Assertion**:
  - Navigate to root `/` and key `routesToCheck`.
  - Capture: Screenshot, Console Logs, and Failed Network Requests.
  - **Fail if**: Console has "Uncaught" / "TypeError", or page body is empty/unmounted.

### STAGE 6 — CLASSIFY & DIAGNOSE
- Map failures to primary classes: `CORS`, `AUTH`, `ENV_CONFIG`, `RUNTIME_JS`, `NETWORK_API`, etc.
- **Search for Solutions**: If `kbMode=web`, search the web for the exact error signature.

### STAGE 7 — FINAL REPORT
Produce a copy-paste friendly report:
- ✅/❌ status for every stage.
- **Root Cause**: The most likely reason for failure.
- **Fix Plan**: Exact commands to run and files to edit.
- **Artifacts**: Paths to screenshots and log files.
