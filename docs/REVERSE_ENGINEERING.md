# Reverse-Engineering Findings & Artifacts

This document details the reverse-engineering analysis of **f.lux 42.2 for macOS**, the tools and procedures used, and where the raw decompilation files are preserved.

---

## 1. Target Identity & Environment

- **Target App:** `/Applications/Flux.app`
- **Bundle ID:** `org.herf.Flux`
- **Version:** 42.2 (Build 42.2, SDK macOS 13.1)
- **Binary:** Mach-O universal binary (x86_64 and arm64).
- **Target Slice:** arm64 slice, SHA-256: `d47cae11f747a2d63a6d09712259d5618a19837393a79594c3182bcef1dac4be`.

---

## 2. REA & Hopper Toolchain Configuration

The analysis was performed using **REA (Reverse Engineer Anything)** integrated with **Hopper Disassembler**:
- **CLI:** `npx -y rea-agents@6.4.0`
- **Hopper Launcher:** `/Users/mduppes/Applications/Hopper Disassembler.app/Contents/MacOS/hopper`
- **Automation Permission:** Requires macOS Apple Events permission between the agent client terminal and `Hopper Disassembler.app`.
- **Environment Variable:** `export HOPPER_LAUNCHER_PATH="/Users/mduppes/Applications/Hopper Disassembler.app/Contents/MacOS/hopper"`

To re-run or inspect an arbitrary procedure:
```sh
export HOPPER_LAUNCHER_PATH="/Users/mduppes/Applications/Hopper Disassembler.app/Contents/MacOS/hopper"
npx -y rea-agents@6.4.0 decompile /Applications/Flux.app/Contents/MacOS/Flux \
    --procedure="-[TintController updateStatus:]" \
    --snapshot flux.snap
```

---

## 3. Preserved Artifacts & Reference Location

All decompilation and static analysis exports are committed directly to this repository under [`reference/`](file:///Users/mduppes/code/Flux/reference/) so any future agent or developer can access them without requiring external tools:

- **Decompiled Pseudocode Directory:**
  [`reference/decompiled/`](file:///Users/mduppes/code/Flux/reference/decompiled/)
  Contains 56 clean `.txt` decompiled methods and helper routines (e.g. `sub_100009f28.txt`, `__TintController_daylightMonitor__.txt`, `__DisplayConfiguration_makeGammaTable__.txt`).
- **Metadata Files:**
  [`reference/metadata/`](file:///Users/mduppes/code/Flux/reference/metadata/)
  - `classes.txt`: Objective-C class catalog and method selectors.
  - `strings.txt`: Extracted strings with cross-reference searches.
- **Complete Raw Archive:**
  [`reference/rea_flux_decompilation.tar.gz`](file:///Users/mduppes/code/Flux/reference/rea_flux_decompilation.tar.gz) (134 KB)
  Contains the complete bundle including REA JSON envelopes, `dispatch.json`, `macho.json`, and trace outputs.
- **Local Scratch Directory (Session backup):**
  `/Users/mduppes/.gemini/antigravity/brain/7816c773-9c80-4c6f-8743-29d9df92048f/scratch/`

---

## 4. Key Decompiled Procedures Summary

### A. Fullscreen Detection Heuristic (`sub_100009f28`)
```c
// Pseudocode summary of sub_100009f28:
r20 = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, 0);
for (window in r20) {
    if (window["kCGWindowOwnerName"] == "Flux") {
        fluxIconVisible = true;
    }
    if (window["kCGWindowOwnerName"] == "Window Server" && 
        window["kCGWindowName"] == "Menubar") {
        menubarCount++;
    }
}
if (menubarCount != displayCount || !fluxIconVisible) {
    setFullscreenDisabled(true);
}
```
**Flaw:** If menu bars are auto-hidden, if a menu bar item hider (e.g. Bartender) conceals the Flux icon, or on certain multi-monitor setups, `menubarCount != displayCount` triggers false fullscreen state and disables warmth across **all** displays.

### B. Timezone & Location Change (`-[TintController daylightMonitor:]`)
- Tracks `lastGMToffset`.
- Compares system UTC offset (`time(&t); localtime_r(&t, &tm); tzset();`).
- When offset shifts, it calls `-[PrefsController updateLocation]`:
  ```objc
  [self.prefsWindow makeKeyAndOrderFront:self];
  [self locateButtonClicked:nil]; // opens web sheet with https://justgetflux.com/minimap.html?geo=...
  ```
**Flaw:** Causes intrusive popups when the system timezone changes, and loads an external web sheet rather than silently recalculating the solar schedule.

### C. Per-App Disable (`sub_10000c218` & `-[TintController syncApp]`)
- Retrieves the frontmost application: `[[NSWorkspace sharedWorkspace] frontmostApplication].bundleIdentifier`.
- If non-nil, checks user defaults key `@"disable-" + bundleIdentifier`.
- If true, sets `self.isAppDisabled = true` and resets gamma.

### D. Gamma Table Construction (`-[DisplayConfiguration makeGammaTable:]`)
- Builds 256/1024-step lookup tables per display:
  `redTable[i] = pow(i / 255.0, gammaR) * rScale;`
- Applies via:
  `CGSetDisplayTransferByTable(displayID, tableSize, redTable, greenTable, blueTable);`

### E. Solar Position Calculations (`sub_100018290` & `sub_1000071f0`)
- Implements standard NOAA solar declination and zenith angles given latitude, longitude, and Julian day.
- Determines dawn, sunrise, solar noon, sunset, and dusk angles (-0.833° standard horizon, -6° civil twilight).
