# Feature Scope & Specifications

This document defines the feature set of the clean-room Flux clone, based on reverse-engineering analysis of f.lux 42.2 and agreed requirements.

## 1. Feature Matrix (Keep vs Drop)

| Category | Feature | Status | Specification / Rationale |
|---|---|---|---|
| **Core** | Day / Sunset / Bedtime schedule | **Keep** | 3 configurable Kelvin targets. Transitions smoothly based on solar elevation and user wake time. |
| **Core** | Smooth animated transitions | **Keep** | Interpolate gamma ramps smoothly across minutes (or quick fade when waking/toggling). |
| **Core** | Menu bar status item | **Keep** | Minimal icon in macOS menu bar with current Kelvin, phase, quick controls, and settings. |
| **Core** | Display gamma adjustments | **Keep** | Apply color changes per display using `CGSetDisplayTransferByTable`. |
| **Disable** | Disable for 1 hour | **Keep** | Temporarily restores normal display gamma for 60 minutes, then resumes schedule. |
| **Disable** | Disable until sunrise | **Keep** | Temporarily restores normal display gamma until next morning's transition begins. |
| **Disable** | Disable for current app | **Keep** | Toggled from the menu for the frontmost app. Untints all displays when a specified application is frontmost (keyed by bundle identifier). |
| **Disable** | Disable for fullscreen apps | **Keep (Improved)** | **Per-display untinting:** Untints *only* the specific monitor running the fullscreen app; other connected displays remain warm. |
| **Location** | Solar calculation from location | **Keep (Improved)** | Background CoreLocation (one-time or significant change) with automatic fallback to timezone center coordinates. No popup windows or web sheets. |
| **Location** | Timezone change detection | **Keep (Improved)** | Recalculates immediately upon `NSSystemTimeZoneDidChangeNotification` without interrupting the user. |
| **Modes** | Movie mode | **Keep** | Warms colors moderately while maintaining shadow detail and video contrast (2.5 hr auto-timeout). |
| **Modes** | Darkroom mode | **Keep** | Monochromatic red tone with inverted luminance for night-time preservation. |
| **System** | macOS Dark Mode sync | **Keep** | Optional automatic switching of macOS appearance between light (day) and dark (sunset). |
| **System** | Start at login | **Keep** | Uses modern `SMAppService` API. |
| **System** | Bedtime reminders | **Keep** | Optional notification before configured bedtime. |
| **Vendor** | Account / Login (`fluxAccount`) | **Drop** | No online accounts, password stores, or authentication. |
| **Vendor** | Analytics / Telemetry (`fluxNetworkQueue`) | **Drop** | Zero network traffic; no logging of screen time, spectrum, or light levels. |
| **Vendor** | Promotional offers (`fluxOffer`) | **Drop** | No promotional dialogs, surveys, or sponsored content. |
| **Vendor** | External web minimap | **Drop** | Replace web-based map sheet with native manual lat/long or timezone selection. |
| **Vendor** | Sparkle auto-updater | **Drop** | No background checking or device profiling via Sparkle. |
| **Vendor** | Hardware light sensors (`fluxSensor`) | **Drop** | Complex proprietary sensor polling dropped in favor of solar schedule. |

---

## 2. Key Behavioral Improvements

### Fullscreen Disable (Per-Display Untinting)
- **Original f.lux Flaw:**
  - Observed in `sub_100009f28` and `observeFullscreen`: Flux checked `NSWorkspaceActiveSpaceDidChangeNotification` and counted visible menu bar windows across displays. If a menu bar was missing or its own icon was hidden, it declared fullscreen and untinted *all* displays globally.
  - Fails with multiple monitors, auto-hiding menu bars, and menu-bar hiders like Bartender.
- **Clone Implementation (built):**
  1. Re-check on `NSWorkspace.didActivateApplicationNotification`, `activeSpaceDidChangeNotification` (and again 1 s later) and on the 30 s tick.
  2. Read on-screen window bounds and layers with `CGWindowListCopyWindowInfo`. No Screen Recording permission is needed.
  3. For each display, take the topmost normal window. If it covers that display's `CGDisplayBounds` (allowing for the notch), the display is full screen.
  4. Only that display goes back to neutral; other displays stay warm. When the full-screen window leaves, the display fades back to the schedule (0.5 s).
  5. Details and edge cases: [ARCHITECTURE.md](ARCHITECTURE.md) section 3 and [ADR 008](DECISIONS.md).

### Location & Timezone Handling
- **Original f.lux Flaw:**
  - Observed in `daylightMonitor:`: Polled UTC offset (`lastGMToffset`). If offset changed, it invoked `-[PrefsController updateLocation]`, which opened the Preferences window and loaded `https://justgetflux.com/minimap.html?geo=<old_text>` in a WebKit sheet.
  - Only requested CoreLocation once upon explicit button click.
- **Clone Implementation (built):**
  1. On first launch of the bundled app, asks for location once through the standard macOS prompt, then requests a single kilometre-accuracy fix at launch, on wake and after a time-zone change.
  2. Each fix is saved together with the time zone it was taken in, and is used only while that zone is current.
  3. Otherwise it uses the coordinates `/usr/share/zoneinfo/zone.tab` gives for `TimeZone.current`, or as a last resort a longitude estimated from the UTC offset. Manual coordinates (a setting, UI in Milestone B) override everything.
  4. On `NSSystemTimeZoneDidChange` it recalculates at once, without opening any UI.
  5. It never makes network requests. The menu shows which location source is in use.

---

## 3. Color Temperature & Gamma Specifications

- **Temperature Range:**
  - Daytime: 5000K – 6500K (default: 6500K).
  - Sunset: 3400K – 4500K (default: 3400K).
  - Bedtime: 1900K – 2700K (default: 2300K).
- **Gamma Curve Generation:**
  - RGB multipliers come from the Planckian locus (Krystek approximation), taken relative to 6500 K so that 6500 K means no change.
  - The multipliers scale each display's own calibrated transfer table (read with `CGGetDisplayTransferByTable`), sized to the display's table capacity.
  - Transitions and blends are interpolated in mired space.
  - A disabled display gets 6500 K (its unmodified base table). Quitting calls `CGDisplayRestoreColorSyncSettings()`.
