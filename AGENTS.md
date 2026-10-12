# Agent guide — start here

This repo is a **clean-room-style clone of f.lux for macOS**. It is a small menu-bar app that warms the screen colour after sunset.
It began with a reverse-engineering pass over the installed f.lux 42.2 (`/Applications/Flux.app`). The goal is to keep the useful features and fix the clunky ones (full-screen disable, time-zone/location handling). Everything tied to the original vendor (account, analytics, offers, auto-updater) is dropped.

## Read these, in order

1. [`docs/STATUS.md`](docs/STATUS.md): **where things stand right now**, the next tasks, and the handoff log. Always read this first.
2. [`docs/FEATURES.md`](docs/FEATURES.md): the agreed feature scope (keep/drop) and the intended behaviour of each feature.
3. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md): stack, module layout, key macOS APIs, data flow.
4. [`docs/DECISIONS.md`](docs/DECISIONS.md): decision log (why things are the way they are). Don't re-litigate settled decisions without the user.
5. [`docs/REVERSE_ENGINEERING.md`](docs/REVERSE_ENGINEERING.md): what f.lux actually does internally, and how to re-run the REA/Hopper analysis if you need more detail. Only needed when you're unsure how the original behaves.

## Rules for every change

- **Keep the docs true.** If a change affects behaviour, structure, or scope, update the matching doc *in the same change*:
  - new or changed feature → `docs/FEATURES.md` (and tick it in `STATUS.md`)
  - new module, file move, new framework or API → `docs/ARCHITECTURE.md`
  - a choice between alternatives, or anything the user decided → add an entry to `docs/DECISIONS.md`
- **Before you stop working** (including when you run low on budget), append an entry to the *Handoff log* in `docs/STATUS.md`: what you did, what's half-done, what's next, and any gotchas. Update the *Next steps* list.
- Ask the user before expanding scope (e.g. ICC-profile colour, new modes, network features). Network calls of any kind are out of scope unless the user approves.
- Keep it simple: plain Swift/SwiftUI/AppKit, no third-party dependencies unless a decision entry justifies one.
- Put pure logic (solar maths, colour curves, schedule) in `FluxCore` with unit tests. Keep OS-touching code thin and in the app target.
- Commit in small, descriptive commits.

## Build / run / test

No Xcode is installed, only Command Line Tools. Everything goes through SwiftPM:

```sh
swift build                 # debug build
swift test                  # unit tests (FluxCore)
./scripts/build-app.sh      # release build → build/<AppName>.app (ad-hoc signed)
open build/*.app
```

(If any of these don't exist yet, check `docs/STATUS.md`; they may still be on the to-do list.)

## Hazards

- **Quit the original f.lux before testing** (`osascript -e 'quit app "Flux"'`). Two apps writing display gamma tables will fight and flicker.
- Gamma tables persist until something resets them. The app must call `CGDisplayRestoreColorSyncSettings()` on quit/crash paths. If a display is stuck tinted during development, run that call (or log out/in).
- Location permission (TCC) is tied to the code signature. Ad-hoc re-signing after each build may make macOS ask again. That's expected in development.
- **Reverse-engineering reference exports:** Decompiled pseudocode and metadata are committed in [`reference/`](file:///Users/mduppes/code/Flux/reference/) (`reference/decompiled/`, `reference/metadata/`, and `reference/rea_flux_decompilation.tar.gz`). Consult these for understanding f.lux behavior, but write clean-room Swift without copying vendor code.
