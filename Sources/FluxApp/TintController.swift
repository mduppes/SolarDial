import AppKit
import FluxCore
import Observation

/// Decides the target for every display and hands it to `DisplayManager`.
/// Re-evaluates on a 30-second tick and whenever an input changes.
@MainActor
@Observable
final class TintController {
    @ObservationIgnored var onUpdate: (() -> Void)?

    let store: SettingsStore
    @ObservationIgnored private let displays: DisplayManager
    @ObservationIgnored private let fullscreen: FullscreenTracker
    @ObservationIgnored private let location: LocationProvider
    @ObservationIgnored private let appearance = AppearanceSync()
    @ObservationIgnored let notifier = Notifier()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var previewEnd: DispatchWorkItem?
    @ObservationIgnored private var lastBedtimeReminder: Date?

    private(set) var schedule: ScheduleResult?
    private(set) var resolvedLocation: ResolvedLocation?
    private(set) var temporaryDisable: TemporaryDisable?
    private(set) var mode: TintMode?
    private(set) var frontApp: NSRunningApplication?
    private(set) var fullscreenDisplays: Set<CGDirectDisplayID> = []
    private var previewKelvin: Double?

    init(store: SettingsStore, displays: DisplayManager, fullscreen: FullscreenTracker, location: LocationProvider) {
        self.store = store
        self.displays = displays
        self.fullscreen = fullscreen
        self.location = location
        displays.onDisplaysChanged = { [weak self] in self?.refresh(fade: 0) }
        fullscreen.onChange = { [weak self] in self?.refresh(fade: 0.5) }
        location.onChange = { [weak self] in self?.refresh(fade: 2) }
        store.onChange = { [weak self] in self?.refresh(fade: 0.5) }
    }

    func start() {
        refresh(fade: 2)
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh(fade: 2) }
        }
        location.refresh()
        if store.settings.bedtimeReminder { notifier.requestAuthorization() }
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
        if let mode, !mode.isActive(at: now) { self.mode = nil }

        let resolved = location.resolve(manual: store.settings.manualCoordinates)
        resolvedLocation = resolved
        let engine = engine(for: resolved)
        let result = engine.evaluate(at: now)
        schedule = result

        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { frontApp = front }

        let ids = displays.activeDisplays()
        fullscreenDisplays = store.settings.disableForFullscreen ? fullscreen.fullscreenDisplays(among: ids) : []

        var targets: [CGDirectDisplayID: DisplayTarget] = [:]
        for id in ids {
            targets[id] = TargetResolver.target(for: .init(
                scheduledKelvin: result.kelvin,
                mode: mode,
                temporarilyDisabled: temporaryDisable != nil,
                appDisabled: isFrontAppDisabled,
                fullscreen: fullscreenDisplays.contains(id),
                previewKelvin: previewKelvin))
        }
        displays.setTargets(targets, fadeDuration: previewKelvin == nil ? fade : 0.15)

        appearance.update(prefersDark: result.prefersDarkAppearance, enabled: store.settings.darkModeSync)
        remindAboutBedtimeIfDue(at: now, engine: engine)
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

    func toggleMovieMode() {
        if case .movie = mode { mode = nil } else { mode = .movie(from: Date()) }
        refresh(fade: 1)
    }

    func toggleDarkroom() {
        if case .darkroom = mode {
            mode = nil
        } else if let resolved = resolvedLocation {
            mode = .darkroomUntilSunrise(from: Date(), schedule: engine(for: resolved))
        }
        refresh(fade: 1)
    }

    func toggleFrontAppDisabled() {
        guard let id = frontApp?.bundleIdentifier else { return }
        if store.settings.disabledBundleIDs.contains(id) {
            store.settings.disabledBundleIDs.remove(id)
        } else {
            store.settings.disabledBundleIDs.insert(id)
        }
    }

    func toggleFullscreenDisable() {
        store.settings.disableForFullscreen.toggle()
    }

    /// Shows `kelvin` on every display for a few seconds, e.g. while a settings slider moves.
    func preview(kelvin: Double) {
        previewKelvin = kelvin
        previewEnd?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.previewKelvin = nil
                self?.refresh(fade: 1)
            }
        }
        previewEnd = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        refresh(fade: 0)
    }

    var isPreviewing: Bool { previewKelvin != nil }

    private func remindAboutBedtimeIfDue(at now: Date, engine: ScheduleEngine) {
        guard store.settings.bedtimeReminder,
              BedtimeReminder.shouldRemind(at: now, schedule: engine, lastReminder: lastBedtimeReminder)
        else { return }
        lastBedtimeReminder = now
        notifier.post(id: "bedtime", title: "Bedtime", body: BedtimeReminder.message(at: now, schedule: engine))
    }

    private func engine(for resolved: ResolvedLocation) -> ScheduleEngine {
        ScheduleEngine(settings: store.settings, coordinates: resolved.coordinates, timeZone: .current)
    }
}
