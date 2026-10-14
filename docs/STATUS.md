# Status & Handoff

## Current Status: SolarDial rename and landing page built; remaining live checks pending

Morning colour is fully on at wake time (or at sunrise, if that is later). The 60-minute transition runs up to that instant. See ADR 013.

- **Phase 1 (Reverse engineering):** Done. Exports are in `reference/`.
- **Phase 2 (Architecture & decisions):** Done. ADR 001–012.
- **Phase 3, Milestone A (core tinter):** Done, and the tint is verified live.
- **Phase 3, Milestone B (settings window, movie mode, start at login, dark-mode sync, bedtime reminder):** Done in code.
- **Phase 3, Milestone C (user feedback round):** Done in code: checkmark menu, narrower status item, app icon, 24-hour graph, colour-conflict warning, bedtime dimming, movie Kelvin and duration, Undo / Reset to Defaults. Darkroom removed.
- 55 unit tests pass and `build/SolarDial.app` builds and runs. App identity and Swift targets are renamed to SolarDial; existing settings are migrated.
- Preview ZIP and SHA-256 checksum published at https://github.com/mduppes/SolarDial/releases/tag/v0.1.0. `netlify.toml` runs the npm/Vite build and publishes generated `website/dist` (Node 22).
- Landing page deployed as an owner-private Sites preview: https://solardial-mac.truedog2.chatgpt.site. Includes a real Apple silicon preview download and the TokenTracking Stripe donate link.

---

## Next Steps

- Donation-page icon is ready for manual upload: `Resources/SolarDial-donation-icon.png` (1024 × 1024 PNG).

- Connect `mduppes/SolarDial` to Netlify: base directory blank/repository root, build `npm run build`, publish `website/dist`. The npm migration and LinkedIn removal are committed locally; push them before deploying. Review the private landing-page preview; hosting/custom-domain setup remains pending. The active checkout is `/Users/mduppes/code/SolarDial`, with remote `git@github.com:mduppes/SolarDial.git`. The full history is preserved and pushed. The old GitHub repo is archived; `/Users/mduppes/code/Flux` contains only a pointer. Its previous checkout is preserved at `/private/tmp/Flux-retired-2026-10-14`.
- SolarDial is running, settings JSON matches the previous clone, Location Services has refreshed, and Start at Login is enabled in the app running from the new SolarDial checkout.

1. **Settings shortcuts follow-up:** rebuilt app is running. Check ⌘W / Escape close Settings while tinting stays active, ⌘M minimizes, ⌘, shows Settings, and existing ⌘Z undoes a settings change. Native menus and app reopen were inspected live; automated keyboard input was inconclusive.
2. **Graph follow-up:** restart the rebuilt app and check the red clock-labelled marker against the axis; leave Settings open for a minute, then close and reopen it. Code now refreshes every 30 s and explicitly on every Settings show. Visual verification is pending.
3. **First live test.** Quit f.lux (`pkill -f /Applications/Flux.app/Contents/MacOS/Flux`) and turn off Night Shift. Then `./scripts/build-app.sh && open build/SolarDial.app`. Check:
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
4. Fix whatever the live test turns up. Likely candidates: the SwiftUI form's sizing, `SMAppService` behaviour with an ad-hoc signature, and notification authorization with an ad-hoc signature.
5. **Ideas (ask the user first):** detect Night Shift (needs private API, so probably not); dim during the day as well as at bedtime; a global hotkey for the disables.

---

## Handoff Log

### 2026-10-14 — Donation-page icon export
- **Done:** Exported the existing SolarDial sunset app/website icon to `Resources/SolarDial-donation-icon.png` for the user's manual donation-page upload. Added export documentation.
- **Verified:** PNG format, 1024 × 1024 pixels; identical to the existing website artwork inspected visually.
- **Next / gotchas:** Upload this PNG in the donation-page editor. No Stripe settings were changed. Website commits remain local; hosting and native live checks above remain pending.

### 2026-10-14 — Remove LinkedIn website links
- **Done:** Removed both LinkedIn links (navigation and footer) and the unused SVG. Updated feature scope, website README, icon guidance and ADR 020.
- **Verified:** Production npm build passes; source and generated HTML contain no LinkedIn links or references.
- **Next / gotchas:** Push local commits and deploy through Netlify when ready. No hosting deployment performed; native live checks remain pending.

### 2026-10-14 — npm website workflow for Netlify
- **Done:** Root npm package with Vite dev/build/preview scripts, lockfile, Node 22 selection, and Netlify build command. Moved HTML/CSS/module JS to `website/` and local icons to `website/public/assets`; `website/dist` is generated and ignored. Local release packages now live in ignored `website/downloads`, safely outside Vite's cleaned output. Updated README, website instructions, architecture, feature scope and ADR 019.
- **Verified:** Locked `npm ci` installation and production build pass. All six distinct built asset references resolve; existing ZIP/checksum preserved. Production preview returns HTTP 200. No Swift code changed.
- **Next / gotchas:** Push the local commit before connecting/deploying Netlify. Base directory must be the repository root (blank), build `npm run build`, publish `website/dist`, Node 22. No Netlify deployment or Sites republication performed. Future Sites publication needs generated `dist` plus the existing hosting manifest. Remaining native live checks above are unchanged.


### 2026-10-14 — Migration completed and pushed to GitHub
- **Done:** Active repository is `/Users/mduppes/code/SolarDial` with origin `git@github.com:mduppes/SolarDial.git`. Full source/docs/reference/rules history transferred and pushed. Current reference paths and website source links point to SolarDial. The old `mduppes/Flux` GitHub repository is archived with a redirect description. The old local checkout, including its caches and local artifacts, is preserved at `/private/tmp/Flux-retired-2026-10-14`; the original Flux directory now contains only README/AGENTS pointers.
- **Release and site:** Published prerelease v0.1.0 with the actual Apple silicon preview ZIP and matching SHA-256 sidecar. Landing-page download links use GitHub release assets, so clean Netlify deployments do not need ignored binary artifacts. Added root `netlify.toml` (publish `website/dist`, no build). Republished the existing private Sites preview successfully with the new GitHub/release links.
- **Verified:** 55 tests pass in the new checkout; signature verification and preview packaging passed. GitHub asset digest matches the local ZIP (`d098b340b356a895bfeb655d631a3dd4cffddde518a3b45eb514251acb3c8b71`). SolarDial process runs from the new build path; native Settings shows Start at Login enabled. All changes are pushed to the new main branch.
- **Next / gotchas:** Netlify config is ready, but no Netlify deployment was performed in this chat. Sites remains owner-private. Open the SolarDial folder as the project for future chats; this chat's old Flux project entry now points at a retired directory. `/private/tmp` backup is temporary; durable source/history is in the new GitHub repo. Remaining live checks above still apply.


### 2026-10-13 — SolarDial rename and website icons
- **Done:** Renamed app, Swift targets/tests, bundle ID, preview ZIP, website and Sites URL to SolarDial (`com.mduppes.solardial`). Missing preferences migrate from Sundial first, then the original clone. Added local GitHub and LinkedIn SVG brand marks to nav/footer, matching hearts on donation links, and a persistent website icon rule. Fixed a stale uppercase heading and an incorrectly renamed vendor attribution in FEATURES. ADR 017.
- **Verified:** all 55 tests; release/signing and ZIP/checksum passed. All icon assets loaded in-browser; 390px viewport had no horizontal overflow. Published https://solardial-mac.truedog2.chatgpt.site, same project/private audience. SolarDial launched; settings match Sundial and saved location is present. Sundial login entry disabled, SolarDial enabled.
- **Next:** user created an empty checkout at `/Users/mduppes/code/SolarDial` with remote `mduppes/SolarDial` and requested moving all work/history there, pushing, and shutting down Flux. Migration is now in progress.


### 2026-10-13 — Rename to Sundial and publish landing page
- **Done:** Renamed package, source targets, tests, menus, window, notification name, app bundle and bundle ID to Sundial (`SundialCore`, `SundialApp`, `SundialCoreTests`, `com.mduppes.sundial`). Startup copies the old clone's settings and saved location fix only for missing new-domain values. Original f.lux identifiers and reference exports are untouched. Current README/agent/build docs updated, ADR 016 added.
- **Landing page:** Buildless `website/dist` with the app icon, clearly labelled illustrative product scene, interactive mired-blended daily curve, features, install notes/FAQ, real ad-hoc-signed Apple silicon ZIP and checksum, and TokenTracking's Stripe donate link. `scripts/package-download.sh` regenerates downloads. Published owner-private Sites preview: https://sundial-mac.truedog2.chatgpt.site (project `appgprj_6acebc66be9081918a95bf0a5fbd19dd`, deployment succeeded). Source publishing used `/private/tmp/sundial-site-6sqjqvfl`, not an embedded Git repo in the app checkout.
- **Verified:** all 55 tests pass with renamed modules; final release/signature/package build passed. Browser checked the desktop layout, 390px responsive overflow, Day/Bedtime buttons, FAQ expansion, and HTTP 200 for page and ZIP. Sundial launched after SIGTERM of the old clone; settings JSON is identical to the old domain. Location Services is active and refreshed its fix, so the new fix differs from the old one. Native window/menu branding confirmed. Old clone's Start at Login was switched off, Sundial's switched on (verified in both UIs).
- **Next / gotchas:** preview is private, Apple silicon only, ad-hoc signed and not notarized. No GitHub release, repository rename, workspace-folder rename, public-site access, or custom domain was created. GitHub links still use `mduppes/Flux`. Generated download files are ignored by the app Git repo but included in the Sites deployment. The app itself still makes no network requests.


### 2026-10-13 — Settings window keyboard commands
- **Done:** `StatusItemManager` installs native application/File/Edit/Window menus: Settings (⌘,), Quit (⌘Q), Hide (⌘H), Close Window (⌘W), Minimize (⌘M), and standard Cut/Copy/Paste/Select All. Nil targets use the responder chain; existing SwiftUI Settings Undo (⌘Z) remains. `SettingsWindow.cancelOperation` handles Escape without closing a parent with an attached sheet. Reopening the running app shows Settings. Docs and ADR 015 updated.
- **Verified:** final release build and signing succeeded; restarted the clone cleanly via SIGTERM. Computer-use observed Settings after reopening and inspected the native File menu's Close Window command. No core logic changed.
- **Limitations / next:** keyboard automation produced inconclusive results (state requests reopen the app, and Escape did not reliably dismiss a menu). Do not claim ⌘W/⌘M/Escape/⌘Z were verified live. Manually check these shortcuts, including sheet cancellation and editing a text field. The rebuilt app is running with Settings open.

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
