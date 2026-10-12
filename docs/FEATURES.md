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
| **Disable** | Disable for current app | **Keep** | Automatically untints when a specified application is frontmost (keyed by bundle identifier). |
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
- **Clone Implementation:**
  1. Observe `NSWorkspace.didActivateApplicationNotification` and `NSWorkspace.activeSpaceDidChangeNotification`.
  2. Inspect window frames of the active application using `CGWindowListCopyWindowInfo`.
  3. Compare window bounds with `NSScreen.screens` frames.
  4. If a window occupies the entire frame of Display $A$, restore default gamma on Display $A$ only. Display $B$ retains its warm color temperature.
  5. When the user leaves fullscreen or switches focus to a standard window on Display $A$, Display $A$ smoothly transitions back to the scheduled color temperature.

### Location & Timezone Handling
- **Original f.lux Flaw:**
  - Observed in `daylightMonitor:`: Polled UTC offset (`lastGMToffset`). If offset changed, it invoked `-[PrefsController updateLocation]`, which opened the Preferences window and loaded `https://justgetflux.com/minimap.html?geo=<old_text>` in a WebKit sheet.
  - Only requested CoreLocation once upon explicit button click.
- **Clone Implementation:**
  1. Requests standard macOS CoreLocation authorization once on first launch with a gentle prompt.
  2. If granted, receives latitude and longitude silently in the background and saves them in `UserDefaults`.
  3. If denied or unavailable, uses the system's `TimeZone.current.identifier` to lookup default coordinates (e.g., center of city/timezone).
  4. Listens for `NSSystemTimeZoneDidChangeNotification`. When the user lands in a new timezone, the app recalculates the solar curve immediately in the background without opening any UI.
  5. Never makes outbound network requests for geocoding or maps.

---

## 3. Color Temperature & Gamma Specifications

- **Temperature Range:**
  - Daytime: 5000K – 6500K (default: 6500K).
  - Sunset: 3400K – 4500K (default: 3400K).
  - Bedtime: 1900K – 2700K (default: 2300K).
- **Gamma Curve Generation:**
  - Calculates RGB multipliers from Color Temperature (Kelvin) using Planckian locus blackbody radiation / Tanner Helland algorithm.
  - Generates linear or power-law transfer tables (256 or 1024 entries per channel).
  - Calls `CGSetDisplayTransferByTable(displayID, tableSize, redTable, greenTable, blueTable)`.
  - When resetting or disabling, calls `CGDisplayRestoreColorSyncSettings()`.
