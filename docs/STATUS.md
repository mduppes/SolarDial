# Status & Handoff

## Current Status: every scoped feature is built; awaiting first live test

- **Phase 1 (Reverse engineering):** Done. Exports are in `reference/`.
- **Phase 2 (Architecture & decisions):** Done. ADR 001–010.
- **Phase 3, Milestone A (core tinter):** Done in code.
- **Phase 3, Milestone B (settings window, movie/darkroom, start at login, dark-mode sync, bedtime reminder):** Done in code.
- 50 unit tests pass and `build/Flux.app` builds. **Nothing has been run live yet** (the original f.lux was running during development).

---

## Next Steps

1. **First live test (do this first).** Quit f.lux (`pkill -f /Applications/Flux.app/Contents/MacOS/Flux`) and turn off Night Shift. Then `./scripts/build-app.sh && open build/Flux.app`. Check:
   - [ ] The tint matches the menu's Kelvin readout, and the fade is smooth.
   - [ ] Quitting from the menu, `kill <pid>` (SIGTERM) and Ctrl-C all restore normal colour.
   - [ ] Full screen: a full-screen video on one display untints only that display. Check a notched MacBook display, and Space switches.
   - [ ] Unplugging/replugging a monitor and sleep/wake re-apply the tint (`DisplayManager.resetAfterReconfiguration`).
   - [ ] Location: the permission prompt appears once, then the menu shows "Location Services". Changing the time zone in System Settings switches to "Time zone (...)" without any window opening.
   - [ ] Settings window: the sliders preview live and return to the schedule about 3 s after release. Wake time and sleep length move the bedtime readout. Manual location works.
   - [ ] Movie mode and darkroom: the darkroom fade looks acceptable (it's a table cross-fade).
   - [ ] Start at login registers (it may need approval in Login Items). Dark-mode sync triggers one Automation prompt. The bedtime reminder appears (notification permission).
2. Fix whatever the live test turns up. Likely candidates: the SwiftUI form's sizing, `SMAppService` behaviour with an ad-hoc signature, and notification authorization with an ad-hoc signature.
3. **Nice to have (ask the user first):** detect Night Shift or another gamma writer and warn; an app icon (`Resources/AppIcon.icns`); a 24-hour colour graph in settings; brightness dimming.

---

## Handoff Log

### 2026-10-12 — Milestone B implementation (Claude Opus)
- **Done:**
  - `FluxCore`: `DisplayTarget` (Kelvin or darkroom) and `TargetFade` (which replaces `KelvinFade`), `TintMode` + `TargetResolver` (ADR 009), `BedtimeReminder`, `ScheduleResult.daylight/bedtime/prefersDarkAppearance`, new settings `darkModeSync` and `bedtimeReminder`, Kelvin ranges. 50 tests.
  - `FluxApp`: `@Observable` `SettingsStore`/`TintController` (a settings change refreshes the displays straight away), slider preview, `System/LaunchAtLogin`, `System/AppearanceSync` (ADR 010), `System/Notifier`, the `UI/PreferencesView` settings window, menu items for Movie Mode, Darkroom and Settings… (⌘,).
  - `Info.plist` now has `NSAppleEventsUsageDescription`.
- **Gotchas:**
  - Changing `store.settings` already triggers `refresh` (through `SettingsStore.onChange`), so don't call `refresh` again after a setting changes.
  - `Notifier` does nothing without a bundle ID (`swift run`), because `UNUserNotificationCenter.current()` would crash there.

### 2026-10-12 — Milestone A implementation (Claude Opus)
- **Done:**
  - `Package.swift` (tools 6.0, macOS 14, Swift 6 mode) with `FluxCore`, `FluxApp`, `FluxCoreTests`.
  - `FluxCore`: NOAA solar calculator (checked against timeanddate.com for São Paulo and London, within 1–2 min), Planckian-locus colour, gamma tables, mired fades, schedule engine (sunset/bedtime/wake model, polar fallback), temporary disables, `zone.tab` parser, location resolver, full-screen geometry, tolerant settings decoding.
  - `FluxApp`: `DisplayManager`, `FullscreenTracker`, `LocationProvider`, `TintController`, `SettingsStore`, `StatusItemManager`, signal handling.
  - `scripts/test.sh`, `scripts/build-app.sh`. The docs (ARCHITECTURE, FEATURES, DECISIONS 006–008) match the code.
- **Deviations from the plan:** full-screen detection uses the topmost window per display rather than the frontmost app's windows (ADR 008), and tests need `scripts/test.sh` (ADR 006).
- **Gotchas:**
  - **Bare `swift test` runs zero tests and still exits 0** with only the Command Line Tools. Use `./scripts/test.sh`.
  - Agent sandboxes break SwiftPM (`sandbox_apply: Operation not permitted`). Run builds outside the sandbox.
  - Core Location is skipped when the binary isn't in the bundle (no usage string), so `swift run` always uses `zone.tab`.
  - The settings are stored as JSON under the `settings` key in the `com.mduppes.flux` defaults domain, and the last fix under `lastLocationFix`. `defaults delete com.mduppes.flux` resets them.

### 2026-10-12 — Reverse engineering & scoping pass (Claude Opus & Gemini Flash)
- Decompiled and mapped `/Applications/Flux.app` (v42.2) with REA and Hopper. The exports are committed in `reference/` (`decompiled/`, `metadata/`, `rea_flux_decompilation.tar.gz`).
- Root causes of the two complaints:
  - *Full-screen disable:* f.lux counts `Menubar` windows owned by `Window Server` and looks for its own menu icon, and only on Space change. This gives false positives with auto-hide menu bars, several monitors and menu-bar managers.
  - *Time zone/location:* when the UTC offset changes, it opens Preferences and a web sheet (`justgetflux.com/minimap.html`) with the old location instead of re-locating.
- The user confirmed the scope: drop all vendor code (account, telemetry, offers, updater), untint per display for full screen, gamma only, modern Swift stack.
