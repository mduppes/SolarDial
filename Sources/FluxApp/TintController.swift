import AppKit
import FluxCore

/// Decides the target temperature for every display and hands it to `DisplayManager`.
/// Re-evaluates on a 30-second tick and whenever an input changes.
@MainActor
final class TintController {
    var onUpdate: (() -> Void)?

    let store: SettingsStore
    private let displays: DisplayManager
    private let fullscreen: FullscreenTracker
    private let location: LocationProvider
    private var timer: Timer?

    private(set) var schedule: ScheduleResult?
    private(set) var resolvedLocation: ResolvedLocation?
    private(set) var temporaryDisable: TemporaryDisable?
    private(set) var frontApp: NSRunningApplication?
    private(set) var fullscreenDisplays: Set<CGDirectDisplayID> = []

    init(store: SettingsStore, displays: DisplayManager, fullscreen: FullscreenTracker, location: LocationProvider) {
        self.store = store
        self.displays = displays
        self.fullscreen = fullscreen
        self.location = location
        displays.onDisplaysChanged = { [weak self] in self?.refresh(fade: 0) }
        fullscreen.onChange = { [weak self] in self?.refresh(fade: 0.5) }
        location.onChange = { [weak self] in self?.refresh(fade: 2) }
    }

    func start() {
        refresh(fade: 2)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(fade: 2) }
        }
        location.refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        displays.restore()
    }

    var isFrontAppDisabled: Bool {
        guard let id = frontApp?.bundleIdentifier else { return false }
        return store.settings.disabledBundleIDs.contains(id)
    }

    func refresh(fade: TimeInterval) {
        let now = Date()
        if let disable = temporaryDisable, !disable.isActive(at: now) { temporaryDisable = nil }

        let resolved = location.resolve(manual: store.settings.manualCoordinates)
        resolvedLocation = resolved
        let result = engine(for: resolved).evaluate(at: now)
        schedule = result

        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { frontApp = front }

        let ids = displays.activeDisplays()
        fullscreenDisplays = store.settings.disableForFullscreen ? fullscreen.fullscreenDisplays(among: ids) : []
        let pausedEverywhere = temporaryDisable != nil || isFrontAppDisabled

        var targets: [CGDirectDisplayID: Double] = [:]
        for id in ids {
            let untinted = pausedEverywhere || fullscreenDisplays.contains(id)
            targets[id] = untinted ? ColorTemperature.neutral : result.kelvin
        }
        displays.setTargets(targets, fadeDuration: fade)
        onUpdate?()
    }

    func disableForAnHour() {
        temporaryDisable = .oneHour(from: Date())
        refresh(fade: 1)
    }

    func disableUntilSunrise() {
        guard let resolved = resolvedLocation else { return }
        temporaryDisable = .untilSunrise(from: Date(), schedule: engine(for: resolved))
        refresh(fade: 1)
    }

    func resume() {
        temporaryDisable = nil
        refresh(fade: 1)
    }

    func toggleFrontAppDisabled() {
        guard let id = frontApp?.bundleIdentifier else { return }
        if store.settings.disabledBundleIDs.contains(id) {
            store.settings.disabledBundleIDs.remove(id)
        } else {
            store.settings.disabledBundleIDs.insert(id)
        }
        refresh(fade: 0.5)
    }

    func toggleFullscreenDisable() {
        store.settings.disableForFullscreen.toggle()
        refresh(fade: 0.5)
    }

    private func engine(for resolved: ResolvedLocation) -> ScheduleEngine {
        ScheduleEngine(settings: store.settings, coordinates: resolved.coordinates, timeZone: .current)
    }
}
