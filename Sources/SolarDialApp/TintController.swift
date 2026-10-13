import AppKit
import SolarDialCore
import Observation

/// Another app that is (or seems to be) changing display colour at the same time as SolarDial.
enum ColourConflict: Equatable {
    case knownApp(String)
    case unknownApp
}

/// Decides the target for every display and hands it to `DisplayManager`.
/// Re-evaluates on a 30-second tick and whenever an input changes.
@MainActor
@Observable
final class TintController {
    /// Apps known to write display gamma, by bundle ID.
    static let knownConflictingApps = ["org.herf.Flux": "f.lux"]

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
    @ObservationIgnored private var lastOverwrite: Date?
    @ObservationIgnored private var notifiedAboutConflict = false

    /// Explicit graph refresh when the retained Settings window is shown again.
    var settingsOpenedAt = Date()

    private(set) var schedule: ScheduleResult?
    private(set) var resolvedLocation: ResolvedLocation?
    private(set) var temporaryDisable: TemporaryDisable?
    private(set) var movieMode: MovieMode?
    private(set) var frontApp: NSRunningApplication?
    private(set) var fullscreenDisplays: Set<CGDirectDisplayID> = []
    private(set) var conflict: ColourConflict?
    private var preview: DisplayTarget?

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

    var engine: ScheduleEngine {
        let coordinates = resolvedLocation?.coordinates
            ?? location.resolve(manual: store.settings.manualCoordinates).coordinates
        return ScheduleEngine(settings: store.settings, coordinates: coordinates, timeZone: .current)
    }

    func refresh(fade: TimeInterval) {
        let now = Date()
        if let disable = temporaryDisable, !disable.isActive(at: now) { temporaryDisable = nil }
        if let movie = movieMode, !movie.isActive(at: now) { movieMode = nil }

        resolvedLocation = location.resolve(manual: store.settings.manualCoordinates)
        let engine = engine
        let result = engine.evaluate(at: now)
        schedule = result

        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { frontApp = front }

        let ids = displays.activeDisplays()
        fullscreenDisplays = store.settings.disableForFullscreen ? fullscreen.fullscreenDisplays(among: ids) : []

        var targets: [CGDirectDisplayID: DisplayTarget] = [:]
        for id in ids {
            targets[id] = TargetResolver.target(for: .init(
                scheduled: result.target,
                movieKelvin: movieMode == nil ? nil : store.settings.movieKelvin,
                temporarilyDisabled: temporaryDisable != nil,
                appDisabled: isFrontAppDisabled,
                fullscreen: fullscreenDisplays.contains(id),
                preview: preview))
        }
        displays.setTargets(targets, fadeDuration: preview == nil ? fade : 0.15)

        updateConflict(at: now)
        appearance.update(prefersDark: result.prefersDarkAppearance, enabled: store.settings.darkModeSync)
        remindAboutBedtimeIfDue(at: now, engine: engine)
        onUpdate?()
    }

    // MARK: Menu actions

    var isDisabledForAnHour: Bool {
        if case .forOneHour = temporaryDisable { return true }
        return false
    }

    var isDisabledUntilSunrise: Bool {
        if case .untilSunrise = temporaryDisable { return true }
        return false
    }

    func toggleDisableForAnHour() {
        temporaryDisable = isDisabledForAnHour ? nil : .oneHour(from: Date())
        refresh(fade: 1)
    }

    func toggleDisableUntilSunrise() {
        temporaryDisable = isDisabledUntilSunrise ? nil : .untilSunrise(from: Date(), schedule: engine)
        refresh(fade: 1)
    }

    func toggleMovieMode() {
        movieMode = movieMode == nil ? .starting(at: Date(), minutes: store.settings.movieMinutes) : nil
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

    // MARK: Previews from the settings window

    func preview(kelvin: Double) {
        show(DisplayTarget(kelvin: kelvin))
    }

    func preview(bedtimeBrightness: Double) {
        show(DisplayTarget(kelvin: store.settings.bedtimeKelvin, brightness: bedtimeBrightness))
    }

    /// Shows `target` on every display for a few seconds after the last call.
    private func show(_ target: DisplayTarget) {
        preview = target
        previewEnd?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.preview = nil
                self?.refresh(fade: 1)
            }
        }
        previewEnd = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        refresh(fade: 0)
    }

    // MARK: Private

    /// Known apps are reported while they run. Unknown writers are reported for 10 minutes after
    /// an overwrite is seen (each overwrite is also undone by `DisplayManager`).
    private func updateConflict(at now: Date) {
        let running = NSWorkspace.shared.runningApplications.compactMap { app in
            app.bundleIdentifier.flatMap { Self.knownConflictingApps[$0] }
        }
        if displays.checkForOverwrites() { lastOverwrite = now }
        if let name = running.first {
            conflict = .knownApp(name)
        } else if let lastOverwrite, now.timeIntervalSince(lastOverwrite) < 600 {
            conflict = .unknownApp
        } else {
            conflict = nil
        }
        if conflict != nil, !notifiedAboutConflict {
            notifiedAboutConflict = true
            notifier.post(id: "conflict", title: "Display colour conflict", body: conflictMessage ?? "")
        }
    }

    var conflictMessage: String? {
        switch conflict {
        case .knownApp(let name): "\(name) is also changing display colour. Quit it to avoid flicker."
        case .unknownApp: "Another app (or Night Shift) is changing display colour."
        case nil: nil
        }
    }

    private func remindAboutBedtimeIfDue(at now: Date, engine: ScheduleEngine) {
        guard store.settings.bedtimeReminder,
              BedtimeReminder.shouldRemind(at: now, schedule: engine, lastReminder: lastBedtimeReminder)
        else { return }
        lastBedtimeReminder = now
        notifier.post(id: "bedtime", title: "Bedtime", body: BedtimeReminder.message(at: now, schedule: engine))
    }
}
