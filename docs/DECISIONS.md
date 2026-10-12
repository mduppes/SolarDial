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
