# Flux (clone)

A minimal, privacy-respecting f.lux-style menu-bar app for recent macOS versions. It warms the display after sunset and has better full-screen and location/time-zone handling than the original.

- Status and next steps: [docs/STATUS.md](docs/STATUS.md)
- Features: [docs/FEATURES.md](docs/FEATURES.md)
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Contributors / AI agents: start at [AGENTS.md](AGENTS.md)

```sh
swift build && swift test
./scripts/build-app.sh && open build/*.app
```

Quit the original f.lux first, because both apps control display gamma.
