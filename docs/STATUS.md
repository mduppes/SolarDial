# Status & Handoff

## Current Status: every scoped feature is built; live visual checks pending

Morning colour is fully on at wake time (or at sunrise, if that is later). The 60-minute transition runs up to that instant. See ADR 013.

- **Phase 1 (Reverse engineering):** Done. Exports are in `reference/`.
- **Phase 2 (Architecture & decisions):** Done. ADR 001–012.
- **Phase 3, Milestone A (core tinter):** Done, and the tint is verified live.
- **Phase 3, Milestone B (settings window, movie mode, start at login, dark-mode sync, bedtime reminder):** Done in code.
- **Phase 3, Milestone C (user feedback round):** Done in code: checkmark menu, narrower status item, app icon, 24-hour graph, colour-conflict warning, bedtime dimming, movie Kelvin and duration, Undo / Reset to Defaults. Darkroom removed.
- 55 unit tests pass and `build/Flux.app` builds and runs.

---

## Next Steps

1. **Graph follow-up:** restart the rebuilt app and check the red clock-labelled marker against the axis; leave Settings open for a minute, then close and reopen it. Code now refreshes every 30 s and explicitly on every Settings show. Visual verification is pending.
2. **First live test.** Quit f.lux (`pkill -f /Applications/Flux.app/Contents/MacOS/Flux`) and turn off Night Shift. Then `./scripts/build-app.sh && open build/Flux.app`. Check:
   - [x] The tint matches the schedule: 2026-10-12 18:33, Florianópolis fix, 5430 K expected; the display table read back as (1, 0.951, 0.878) against (1, 0.9507, 0.8772) expected, with the calibrated mid-table kept. The menu readout and fade smoothness still need a visual check.
   - [ ] Quitting from the menu, `kill <pid>` (SIGTERM) and Ctrl-C all restore normal colour. (SIGTERM verified: the table is back to identity. Menu Quit and Ctrl-C are untested.)
   - [ ] Full screen: a full-screen video on one display untints only that display. Check a notched MacBook display, and Space switches.
   - [ ] Unplugging/replugging a monitor and sleep/wake re-apply the tint (`DisplayManager.resetAfterReconfiguration`).
   - [ ] Location: (a Core Location fix was received and stored on first launch, tagged `America/Sao_Paulo`) the permission prompt appears once, then the menu shows "Location Services". Changing the time zone in System Settings switches to "Time zone (...)" without any window opening.
   - [ ] Settings window: the sliders preview live and return to the schedule about 3 s after release. Wake time and sleep length move the bedtime readout. Manual location works.
   - [ ] Movie mode shows the chosen Kelvin and turns off after the chosen time; its menu item is checked while on.
   - [ ] Menu: the five toggles show checkmarks correctly; the status item is no wider than its neighbours.
   - [ ] Settings: the graph renders (gradient fill, sunrise/sunset/now lines), the dimming slider previews, Undo and Reset to Defaults work, and the window fits on a laptop screen (it's 720 pt tall and scrolls).
   - [ ] Conflict warning: launching f.lux shows the ⚠︎ line and icon and one notification.
   - [ ] The Finder/Login Items show the new icon.
   - [ ] Start at login registers (it may need approval in Login Items). Dark-mode sync triggers one Automation prompt. The bedtime reminder appears (notification permission).
3. Fix whatever the live test turns up. Likely candidates: the SwiftUI form's sizing, `SMAppService` behaviour with an ad-hoc signature, and notification authorization with an ad-hoc signature.
4. **Ideas (ask the user first):** detect Night Shift (needs private API, so probably not); dim during the day as well as at bedtime; a global hotkey for the disables.

---

## Handoff Log

### 2026-10-13 — Refresh the graph clock
- **Done:** `DailyGraphView` has a 30-second `TimelineView`, and `PreferencesWindowController.show()` updates an observable timestamp on every Settings open, including reopening the retained window. The marker now has a clock label; both marker and axis labels explicitly use the schedule time zone. Curve, Kelvin readout and marker use the same instant, including after midnight. Features and architecture docs updated.
- **Verified:** debug build and 55 core tests passed; the final release app bundle rebuilt successfully. No schedule or gamma behaviour changed.
- **Next:** restart `build/Flux.app` and visually check marker placement, periodic refresh and close/reopen refresh. Live UI behaviour has not been verified.

### 2026-10-13 — Morning tint past wake time
- **Done:** The morning ramps finish at the later of sunrise and wake, instead of starting there. Wake is the clock time on that local calendar day (year/month/day components), not `Calendar.date(bySettingHour:of:)`. Regression test uses the reported Florianópolis inputs at 2026-10-13 07:11 BRT (10:11Z). 55 tests. ADR 013. Docs updated.
- **Ruled out:** sunrise that morning is ~05:40, so it was not holding the tint; `sleepMinutes` 510 is 8 h 30 min (bedtime 22:30); `org.herf.Flux` is only the conflict-detection bundle id (wake time 480 and 42.6° N, 18.1° E are not read); `ScheduleEngine` keeps no day cache, so being open since Oct 12 19:42 does not change `evaluate`.
- **Not done:** no live gamma check of this build. "Disable until sunrise" now ends when the ramp begins (06:00 with the defaults).

### 2026-10-12 — Milestone C: user feedback round (Claude Opus)
- **Done:**
  - `FluxCore`: darkroom removed. `DisplayTarget` is now Kelvin + brightness. `MovieMode` uses an exact Kelvin and duration, `TintMode.swift` was renamed to `TargetResolver.swift`. Added `ScheduleResult.brightness` (bedtime dimming), `ScheduleEngine.dailyCurve`, `SettingsHistory` (undo) and `GammaTable.approximatelyEquals`. New settings: `bedtimeBrightness`, `movieKelvin` and `movieMinutes`. 53 tests.
  - `FluxApp`: the menu has fixed items with checkmarks, and the status item uses `variableLength` with a 14 pt symbol. Added conflict detection (`DisplayManager.checkForOverwrites`, known apps in `TintController`), Undo/Reset in `SettingsStore`, and in settings the graph (`UI/DailyGraphView`, Swift Charts), movie and dimming controls, a conflict banner and an Undo/Reset footer.
  - Icon: `scripts/make-icon.swift` writes `Resources/AppIcon.icns`, and `build-app.sh` copies it and sets `CFBundleIconFile`.
  - ADR 009 is superseded by ADR 011 (no darkroom, exact movie Kelvin, gamma dimming). ADR 012 covers conflict detection.
- **Verified live:** the new build runs and the table read back matches the sunset ramp. The menu, settings window and icon haven't been checked visually, because the agent has no Screen Recording permission.
- **Gotchas:**
  - Two table writers (for example f.lux) now fight every 30 s, because Flux rewrites its tables. Quit f.lux.
  - Old settings JSON decodes fine: the new keys get defaults, and the old darkroom state isn't persisted.

### 2026-10-12 — First live run (Claude Opus)
- Quit f.lux and launched `build/Flux.app`. Verified by reading gamma back with `CGGetDisplayTransferByTable`: the tint matches `ScheduleEngine` output, SIGTERM restores identity, and relaunch re-applies. Core Location returned a fix with no visible fuss.
- The agent couldn't take screenshots (no Screen Recording permission), so the visual checks (menu, settings window, full screen, fade smoothness) are left to the user.
- A handy check: compile `Sources/FluxCore/**/*.swift` together with a small `main.swift` using `swiftc` to print what the schedule gives for any coordinates and time.

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
