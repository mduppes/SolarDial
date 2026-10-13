# Architectural Decision Records (ADR)

This log records settled architectural decisions. Do not re-litigate settled decisions without user approval.

---

### ADR 001: Clean-room Drop of Vendor Services & Telemetry
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** Reverse-engineering of f.lux 42.2 revealed classes `fluxAccount`, `fluxNetworkQueue`, `fluxOffer`, `fluxSensor`, and Sparkle autoupdating with hardware profiling. These perform recurring network requests, data uploads, and promotional notifications.
- **Decision:** Eliminate all vendor-specific features. The clone will make zero outbound network requests. No account system, no telemetry/metrics, no promotional offers, and no Sparkle framework.
- **Consequences:** Significantly simpler codebase, zero telemetry/privacy concerns, lighter memory footprint, zero network failure modes.

---

### ADR 002: Per-Display Fullscreen Disable
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** f.lux 42.2 uses a crude heuristic counting MenuBar windows (`sub_100009f28`). When triggered, it untints all monitors simultaneously, which disrupts multi-monitor workflows (e.g. watching video fullscreen on one display while working on another).
- **Decision:** Implement per-display fullscreen detection using `CGWindowListCopyWindowInfo` matched against `NSScreen` frames. When a fullscreen window is detected, untint **only** the monitor hosting the fullscreen application. Secondary monitors remain warm.
- **Consequences:** Resolves the user's primary complaint about f.lux clunkiness. Requires tracking active display states independently.

---

### ADR 003: Gamma LUT Manipulation via CoreGraphics
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** f.lux has two mechanisms: setting display gamma ramps (`CGSetDisplayTransferByTable`) and generating modified ColorSync ICC profiles in `~/Library/ColorSync/Profiles/f.lux`. Generating and installing ICC profiles can leave persistent tint on disk if the app crashes, and conflicts with system ColorSync calibration.
- **Decision:** Use gamma table manipulation (`CGSetDisplayTransferByTable`) only. Do not write or replace ICC profiles on disk. Always provide fail-safe cleanup via `CGDisplayRestoreColorSyncSettings()`.
- **Consequences:** Clean separation from system color management; instantaneous transitions without disk I/O; clean revert on exit.

---

### ADR 004: Toolchain and Platform Target
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** The development machine has macOS 26.x with Apple Command Line Tools (Swift 6.3), without full Xcode installed. f.lux 42.2 targeted macOS 10.9 with legacy Objective-C code.
- **Decision:** Build entirely with modern SwiftPM targeting macOS 14.0+ (Sonoma) and later. Package the resulting executable into a standalone `.app` bundle via a shell script (`scripts/build-app.sh`). Avoid third-party package dependencies.
- **Consequences:** Zero Xcode requirement; modern Swift concurrency (`async`/`await`, `Sendable`); uses modern macOS APIs like `SMAppService` instead of legacy login items.

---

### ADR 005: Non-Intrusive Location & Timezone Resolution
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** f.lux pops up a preference window and an embedded WebKit sheet loading `justgetflux.com/minimap.html` whenever the system time offset changes. Additionally, its saved location easily desyncs from the active timezone (e.g. saved location in Europe while operating on UTC-3).
- **Decision:** 
  1. Use CoreLocation once/passively in the background without UI interruption.
  2. If permission is denied, use a static mapping table from system timezone ID (e.g., `America/Argentina/Buenos_Aires`) to approximate center coordinates.
  3. Listen to `NSSystemTimeZoneDidChangeNotification` and recalculate the solar curve seamlessly in the background without popping up any windows.
- **Consequences:** Resolves the second primary user complaint regarding timezone clunkiness. Fully offline and unobtrusive.
- **Refined by ADR 007:** the "static mapping table" is the system's `zone.tab`.

---

### ADR 006: Swift Testing via `scripts/test.sh`
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** The Command Line Tools ship `Testing.framework` (Swift Testing) but no `XCTest.framework`. Swift Testing lives in `$(xcode-select -p)/Library/Developer/Frameworks`, which isn't on the search path. Per-target `unsafeFlags` in `Package.swift` aren't enough: SwiftPM's generated test runner is compiled without them, its `#if canImport(Testing)` is false, and `swift test` silently runs zero tests and exits 0.
- **Decision:** Write tests with Swift Testing. Run them through `scripts/test.sh`, which passes `-F` and the two rpaths (`Frameworks`, `usr/lib` for `lib_TestingInterop.dylib`) globally to `swift test`. Keep `Package.swift` free of unsafe flags. With a full Xcode installed, the script falls through to plain `swift test`.
- **Consequences:** `swift test` on its own looks green but tests nothing. Always use the script.

---

### ADR 007: `zone.tab` as the location fallback, with time-zone-tagged fixes
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** ADR 005 called for a hand-written time zone to coordinate table. macOS already ships `/usr/share/zoneinfo/zone.tab` (IANA, updated with the OS), which has an ISO 6709 coordinate for every zone ID. f.lux's real failure was a *stale* saved location (Dubrovnik while the clock was on UTC-3).
- **Decision:** Parse `zone.tab` (`FluxCore/Location/ZoneTab.swift`). Store each Core Location fix together with the time-zone ID that was current when it was taken, and use it only while that zone is still current. Otherwise fall back to `zone.tab`, and as a last resort estimate the longitude from the UTC offset.
- **Consequences:** No table to maintain. Travelling can never leave an old location in use. The fallback is accurate to within the zone's size (usually good enough for sunset to within a few minutes in smaller zones).

---

### ADR 008: Full-screen detection uses the topmost window per display
- **Date:** 2026-10-12
- **Status:** Accepted (refines ADR 002)
- **Context:** The first plan only checked the frontmost app's windows. That misses the case ADR 002 cites: a full-screen video on display B while the user works in another app on display A.
- **Decision:** For each display, take the topmost on-screen window at layer 0 or at the shielding level (not Flux's own, not transparent) that intersects it. If it covers `CGDisplayBounds` (with notch slack), untint that display. The selection logic is pure (`FullscreenGeometry.fullscreenDisplays`) and unit-tested.
- **Consequences:** It works on several monitors at once and needs no Screen Recording permission. A zoomed window fills the screen when the menu bar is set to auto-hide, so it counts as full screen. That's accepted for now.

---

### ADR 009: Mode precedence, movie and darkroom definitions
- **Date:** 2026-10-12
- **Status:** Superseded by ADR 011
- **Context:** f.lux's `computeEffects:pr:` overrides the scheduled Kelvin for movie mode and sets a flag for darkroom. Its exact constants aren't readable from the decompile, and the clone needs explicit rules for how modes combine with the disables.
- **Decision:** All the rules are in one pure function, `TargetResolver.target(for:)`. Precedence: preview, then temporary disable, then darkroom, then per-app/full-screen disable, then movie, then schedule.
  - Movie mode is `max(scheduled, 4100 K)` for 2.5 h.
  - Darkroom uses the display's red curve inverted (green and blue zero) until the next morning. It overrides the per-app and full-screen disables, because a bright full-screen window is what darkroom exists to prevent.
- **Consequences:** It's easy to test and change. The movie-mode Kelvin is our own choice, not f.lux's.

---

### ADR 010: Dark Mode via System Events, edge-triggered
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** There's no public API for setting the system appearance. f.lux runs bundled `darkmode.scpt`/`lightmode.scpt` through `system("/usr/bin/osascript ...")`.
- **Decision:** Run `osascript` with an inline System Events command through `Process` (no shell). Act only when `prefersDarkAppearance` changes (daylight weight crosses 0.5), and skip it if the appearance already matches.
- **Consequences:** It needs one Automation permission prompt (`NSAppleEventsUsageDescription` is in `Info.plist`). A manual appearance change made by the user lasts until the next sunset or sunrise.

---

### ADR 011: No darkroom; movie Kelvin is exact; dimming through the gamma tables
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** The user asked to drop darkroom, to choose movie mode's exact Kelvin, and for brightness dimming.
- **Decision:**
  - Darkroom is removed. `DisplayTarget` is now Kelvin + brightness, which makes every fade a simple blend.
  - Precedence: preview, then any disable (temporary, per-app, full-screen), then movie, then schedule.
  - Movie mode shows exactly `movieKelvin` (2700–6500 K, default 4100 K) for `movieMinutes`. It's not `max(scheduled, …)` any more, so it can be cooler or warmer than the schedule.
  - Dimming multiplies the gamma tables (`bedtimeBrightness`, 40–100 %, following the bedtime ramp), instead of using display brightness APIs. Those are private or only work on built-in displays.
- **Consequences:** Dimming lowers peak white but not the backlight, so it saves no power. Movie mode and disables show full brightness.

---

### ADR 012: Detecting other colour apps by reading the tables back
- **Date:** 2026-10-12
- **Status:** Accepted
- **Context:** The user asked for a warning when another app changes display colour. There's no notification for transfer-table changes.
- **Decision:** On each 30 s tick, read the tables back and compare them with what Flux last wrote (with a grace period after fades, launches and reconfigurations). On a mismatch, rewrite the table and flag an "unknown app" conflict for 10 minutes. Also flag known apps (f.lux) by bundle ID when they're running. The warning appears in the menu, in settings, and as a notification once per session.
- **Consequences:** It's cheap and needs no permission. It can't see Night Shift or True Tone, which work below the tables. Two table writers will still fight every 30 s until one quits, but the user is told why.

---

### ADR 013: The morning transition ends at wake (or at sunrise, if that is later)
- **Date:** 2026-10-13
- **Status:** Accepted
- **Context:** At 2026-10-13 07:11 in America/Sao_Paulo (10:11Z), Florianópolis, with wake time 07:00 and a 60-minute transition, the screen was still about 2470 K. Sunrise that day is about 05:40, so the sun was not holding the tint. `sleepMinutes` 510 is a duration (8 h 30 min), which puts bedtime at 22:30, not a clock time. Nothing reads the original f.lux defaults (`org.herf.Flux` wake time 480 or the saved 42.6° N, 18.1° E location); that bundle id is only used to notice when f.lux is running. The schedule is stateless, so an app that had been open since the previous evening was not reusing a cached day. The bedtime ramp already finishes at bedtime, but the morning ramps started at wake and ran for `transitionMinutes` afterward. Eleven minutes into that hour, bedtime weight was still about 0.82.
- **Decision:** Daytime colour, and the release of bedtime colour, are complete at the later of this local day's sunrise and wake time. The transition occupies the `transitionMinutes` before that instant. Wake is built from the calendar day of the instant being evaluated, not from `Calendar.date(bySettingHour:of:)`, whose default search direction is forward.
- **Consequences:** "Disable until sunrise" ends when that morning ramp begins (06:00, with the defaults). Dark-mode sync's morning crossing (daylight weight 0.5) moves earlier by half the transition. Sunset still starts its ramp at sunset.


### ADR 014: Refresh the graph on every Settings open
- **Date:** 2026-10-13
- **Status:** Accepted
- **Context:** The graph read `Date()` only during incidental SwiftUI redraws, which could leave its current-time marker stale. The user requested an immediate refresh whenever Settings loads. The Settings window is retained when closed.
- **Decision:** Refresh the graph every 30 seconds via `TimelineView`, and update an observable opening timestamp in `PreferencesWindowController.show()` on every invocation. Use the newer timestamp for the entire graph. Label the marker with the clock time in the same time zone as the schedule and axis.
- **Consequences:** Reopening Settings refreshes immediately even if SwiftUI does not send another appearance event; the graph's day rolls over with its clock.


### ADR 015: Native menus for Settings keyboard commands
- **Date:** 2026-10-13
- **Status:** Accepted
- **Context:** The app had only an NSStatusItem menu, leaving standard window and text-editing shortcuts without application-menu commands. The user requested working Settings window shortcuts.
- **Decision:** Install a native application menu with Settings, Quit and Hide, a File menu with Close Window, an Edit menu with text-editing commands, and a Window menu with Minimize. Use the responder chain for native commands instead of intercepting global keystrokes. Keep the existing SwiftUI Settings Undo shortcut. Handle Escape at the Settings window only after controls, without closing an attached sheet's parent. Reopening the running app brings Settings forward.
- **Consequences:** Window and editing commands remain local to Flux; closing Settings leaves the menu-bar app running. No global shortcut permission is needed.
