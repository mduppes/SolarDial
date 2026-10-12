# Status & Handoff

## Current Status: Phase 1 (Reverse Engineering & Architectural Alignment) Complete

- **Phase 1 (Reverse Engineering):** Done. Analyzed `/Applications/Flux.app` 42.2 using REA and Hopper Disassembler. Extracted and decompiled 44+ key routines. Identified exact root causes of fullscreen and timezone clunkiness. Decompilation artifacts archived.
- **Phase 2 (Architecture & Decisions):** Done. User agreed on four core design decisions (drop vendor baggage, per-display fullscreen disable, gamma-only color adjustments, modern SwiftPM stack targeting recent macOS).
- **Phase 3 (Implementation):** Next to begin.

---

## Next Steps

1. **Initialize SwiftPM Project:**
   - Create `Package.swift` with two targets:
     - `FluxCore` (pure Swift library, cross-platform / testable on CLI, no AppKit/CoreGraphics dependencies).
     - `FluxApp` (macOS executable target, AppKit/SwiftUI menu-bar app).
     - `FluxCoreTests` (XCTest suite for solar & gamma math).
2. **Implement `FluxCore`:**
   - [ ] Solar math (`SolarCalculator.swift`): sunrise, sunset, dusk, dawn, solar altitude given latitude, longitude, and date.
   - [ ] Color temperature & gamma table conversion (`ColorRamp.swift`): Planckian blackbody / Kelvin to RGB gamma tables (1000K to 6500K).
   - [ ] Schedule engine (`Schedule.swift`): State machine evaluating current target temperature from day/sunset/bedtime targets and wake time.
   - [ ] Unit tests for solar altitude and gamma ramp calculations.
3. **Implement Display Management in `FluxApp`:**
   - [ ] `DisplayController.swift`: Apply gamma ramps using `CGSetDisplayTransferByTable`.
   - [ ] Safety & restoration: Register signal handlers and app termination hooks to always restore displays via `CGDisplayRestoreColorSyncSettings()`.
   - [ ] Monitor display addition, removal, and wake events via `CGDisplayRegisterReconfigurationCallback`.
4. **Implement Fullscreen & Per-Display Untinting:**
   - [ ] `FullscreenDetector.swift`: Listen to `NSWorkspace.didActivateApplicationNotification` and `activeSpaceDidChangeNotification`.
   - [ ] Query on-screen window frames using `CGWindowListCopyWindowInfo` to detect which specific display is occupied by a fullscreen window.
   - [ ] Per-display disable: Untint *only* the fullscreen display, preserving warmth on secondary displays.
5. **Implement Location & Timezone Service:**
   - [ ] `LocationManager.swift`: Quiet CoreLocation resolution (one-shot or significant change).
   - [ ] Listen to `NSSystemTimeZoneDidChangeNotification`.
   - [ ] Fallback to approximate timezone center coordinates if CoreLocation is denied—no popups or external web minimaps.
6. **Implement Menu Bar & Preferences UI:**
   - [ ] `StatusBarItem.swift`: Clean menu-bar icon, quick toggle, temperature readouts, temporary disable options (1 hour, until sunrise, for current app).
   - [ ] Preferences window in SwiftUI: Day, sunset, bedtime sliders, wake time picker, fullscreen toggle.
7. **Packaging & Build Script:**
   - [ ] `./scripts/build-app.sh`: Compile release binary with `swift build -c release`, build `.app` bundle, generate `Info.plist` (`LSUIElement = true`), and ad-hoc sign.

---

## Handoff Log

### 2026-10-12 — Reverse Engineering & Scoping Pass (Claude Opus & Gemini Flash)
- **Completed:**
  - Decompiled and mapped `/Applications/Flux.app` (v42.2) using REA and Hopper Disassembler.
  - Documented root causes of existing flaws:
    - *Fullscreen disable:* Heuristic counted `Menubar` windows from `Window Server` and looked for `Flux`'s menu icon on Space change, causing false positives with auto-hide menu bars, multiple monitors, and third-party menu bar managers.
    - *Timezone/Location:* Compared UTC offset on timer; on change, popped the main preferences window and opened an external web sheet at `justgetflux.com/minimap.html` querying the old location.
  - User confirmed feature scope:
    - Drop all vendor-specific code (accounts, telemetry, promos, auto-updater).
    - Per-display fullscreen disable (untint only the screen hosting the fullscreen app).
    - Gamma table manipulation (`CGSetDisplayTransferByTable`) without touching ColorSync profiles.
    - Clean modern Swift stack, no legacy baggage.
  - Decompilation files archived in scratch directory (`rea_flux_decompilation.tar.gz`).
  - Completed documentation suite in `docs/`: `STATUS.md`, `FEATURES.md`, `ARCHITECTURE.md`, `DECISIONS.md`, and `REVERSE_ENGINEERING.md`.
- **In Progress / Next:**
  - Setting up `Package.swift` and implementing `FluxCore` (solar math and gamma ramp calculation).
- **Gotchas / Notes:**
  - Quit the original f.lux app (`osascript -e 'quit app "Flux"'`) before running display gamma tests.
  - Always guarantee `CGDisplayRestoreColorSyncSettings()` runs on app termination or unhandled signal exit.
