# Status & Handoff

## Current Status: Milestone A (working menu-bar tinter) built; awaiting first live test

- **Phase 1 (Reverse engineering):** Done. Exports are in `reference/`.
- **Phase 2 (Architecture & decisions):** Done. ADR 001–008.
- **Phase 3, Milestone A (core tinter):** Code done, unit-tested (38 tests) and builds as `build/Flux.app`. **Not yet run live** against real displays (the original f.lux was running during development).
- **Phase 3, Milestone B (remaining scoped features):** Not started.

---

## Next Steps

1. **First live test (do this first).** Quit f.lux (`pkill -f /Applications/Flux.app/Contents/MacOS/Flux`) and turn off Night Shift. Then `./scripts/build-app.sh && open build/Flux.app`. Check:
   - [ ] The tint matches the menu's Kelvin readout, and the fade is smooth.
   - [ ] Quitting from the menu, `kill <pid>` (SIGTERM) and Ctrl-C all restore normal colour.
   - [ ] Full screen: a full-screen video on one display untints only that display. Check a notched MacBook display, and Space switches.
   - [ ] Unplugging/replugging a monitor and sleep/wake re-apply the tint (`DisplayManager.resetAfterReconfiguration`).
   - [ ] Location: the permission prompt appears once, then the menu shows "Location Services". Changing the time zone in System Settings switches to "Time zone (...)" without any window opening.
2. **Milestone B: settings UI** (`UI/PreferencesView.swift`, SwiftUI window opened from the menu): Kelvin sliders for day, sunset and bedtime, wake time, sleep length, transition length, manual latitude/longitude, and the per-app disable list. The `UserSettings` fields already exist.
3. **Milestone B: modes.** Movie mode (warm but contrast-preserving, auto-off after 2.5 h) and Darkroom (red, inverted). Both need new table shapes in `GammaTable`; check `reference/decompiled/__TintController_computeEffects_pr__.txt` for how f.lux did it.
4. **Milestone B: system integration.** Start at login (`SMAppService.mainApp`), dark-mode sync, bedtime reminder notification.
5. **Nice to have:** detect Night Shift or another gamma writer and warn; an app icon (`Resources/AppIcon.icns`).

---

## Handoff Log

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
