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
