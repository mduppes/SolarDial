# SolarDial

A minimal, privacy-respecting menu-bar app for recent macOS versions. It warms the display after sunset and has better full-screen and location/time-zone handling than the original.

- Status and next steps: [docs/STATUS.md](docs/STATUS.md)
- Features: [docs/FEATURES.md](docs/FEATURES.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Contributors / AI agents: start at [AGENTS.md](AGENTS.md)

```sh
swift build && ./scripts/test.sh
./scripts/build-app.sh && open build/SolarDial.app
```

Quit the original f.lux first, because both apps control display gamma.

## Landing page

The landing page lives in [website/](website/README.md). It includes a daily-schedule illustration, installation notes, and the same Stripe-hosted donate link as TokenTracking.

```sh
./scripts/build-app.sh
./scripts/package-download.sh
python3 -m http.server 8765 --directory website/dist --bind 127.0.0.1
```

The packaged preview targets Apple silicon and macOS 14+. It is ad-hoc signed and not notarized. Existing preferences from the earlier clone migrate automatically; macOS may ask again for permissions or Start at Login approval after the rename.
