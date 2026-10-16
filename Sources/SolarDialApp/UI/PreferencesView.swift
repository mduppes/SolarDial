import AppKit
import SolarDialCore
import SwiftUI

struct PreferencesView: View {
    @Bindable var store: SettingsStore
    let controller: TintController

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginNeedsApproval = LaunchAtLogin.needsApproval
    @State private var loginError: String?
    @State private var confirmReset = false
    /// Starts open when any day has its own wake time, so the overrides aren't hidden.
    @State private var showWeekdayWake: Bool

    init(store: SettingsStore, controller: TintController) {
        self.store = store
        self.controller = controller
        _showWeekdayWake = State(initialValue: !store.settings.wakeMinutesByWeekday.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                if let warning = controller.conflictMessage {
                    Section {
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                Section("Today") {
                    DailyGraphView(controller: controller)
                }
                colourSection
                movieSection
                scheduleSection
                locationSection
                disableSection
                systemSection
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 500, height: 720)
    }

    private var footer: some View {
        HStack {
            Button("Undo") { store.undo() }
                .keyboardShortcut("z")
                .disabled(!store.canUndo)
            Spacer()
            Link(destination: URL(string: "https://solardial.netlify.app/")!) {
                Label("solardial.netlify.app", systemImage: "globe")
            }
            .help("Open the SolarDial website")
            Spacer()
            Button("Reset to Defaults…") { confirmReset = true }
        }
        .padding(12)
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { store.resetToDefaults() }
        } message: {
            Text("Colours, schedule, location, disabled apps and options go back to factory settings. You can undo this.")
        }
    }

    // MARK: Sections

    private var colourSection: some View {
        Section {
            kelvinSlider("Daytime", \.dayKelvin, UserSettings.dayKelvinRange)
            kelvinSlider("Sunset", \.sunsetKelvin, UserSettings.sunsetKelvinRange)
            kelvinSlider("Bedtime", \.bedtimeKelvin, UserSettings.bedtimeKelvinRange)
            LabeledContent("Dim at bedtime") {
                HStack {
                    Slider(value: bedtimeBrightness, in: UserSettings.bedtimeBrightnessRange, step: 0.05)
                    Text(store.settings.bedtimeBrightness >= 1
                        ? "Off" : "\(Int((store.settings.bedtimeBrightness * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
            }
        } header: {
            Text("Colour")
        } footer: {
            Text("Moving a slider previews it for a few seconds. Dimming scales the colour tables, so it works on every display, including ones without brightness control.")
                .foregroundStyle(.secondary)
        }
    }

    private var movieSection: some View {
        Section("Movie Mode") {
            kelvinSlider("Colour", \.movieKelvin, UserSettings.movieKelvinRange)
            Picker("Lasts", selection: $store.settings.movieMinutes) {
                ForEach([60, 90, 120, 150, 180, 240], id: \.self) { minutes in
                    Text(duration(minutes)).tag(minutes)
                }
            }
        }
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker("Wake time", selection: wakeTime, displayedComponents: .hourAndMinute)
            DisclosureGroup("Wake time by day", isExpanded: $showWeekdayWake) {
                ForEach(orderedWeekdays, id: \.self) { weekday in
                    weekdayWakeRow(weekday)
                }
            }
            Stepper(value: $store.settings.sleepMinutes, in: 300...720, step: 30) {
                LabeledContent("Sleep length", value: duration(store.settings.sleepMinutes))
            }
            if store.settings.wakeMinutesByWeekday.isEmpty {
                LabeledContent("Bedtime", value: clock(store.settings.bedtimeMinutes))
            } else {
                LabeledContent("Bedtime tonight", value: clock(tonightsBedtime))
            }
            Picker("Transition speed", selection: $store.settings.transitionMinutes) {
                Text("Fast (20 minutes)").tag(20)
                Text("Slow (60 minutes)").tag(60)
            }
        }
    }

    private var locationSection: some View {
        Section {
            Toggle("Set time zone manually", isOn: manualLocation)
            if let manual = store.settings.manualTimeZone {
                LabeledContent("Time zone") {
                    Menu(zoneLabel(manual)) {
                        ForEach(zonesByRegion, id: \.region) { group in
                            Menu(group.region) {
                                ForEach(group.zones, id: \.self) { id in
                                    Button(zoneLabel(id, inRegion: true)) { store.settings.manualTimeZone = id }
                                }
                            }
                        }
                    }
                    .fixedSize()
                }
            }
            if let resolved = controller.resolvedLocation {
                LabeledContent("Using", value: describe(resolved))
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Sunrise and sunset come from Location Services when allowed, otherwise from the main city of your time zone. A manual time zone only moves the sun; wake and bedtime still follow your Mac's clock. Nothing is sent over the network.")
                .foregroundStyle(.secondary)
        }
    }

    private var disableSection: some View {
        Section {
            Toggle("Untint displays showing a full-screen app", isOn: $store.settings.disableForFullscreen)
            if store.settings.disabledBundleIDs.isEmpty {
                Text("No apps disabled. Use “Disable for …” in the menu while an app is in front.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.settings.disabledBundleIDs.sorted(), id: \.self) { id in
                    HStack {
                        Text(appName(for: id))
                        Spacer()
                        Button("Remove") { store.settings.disabledBundleIDs.remove(id) }
                    }
                }
            }
        } header: {
            Text("Disable")
        }
    }

    private var systemSection: some View {
        Section("System") {
            Toggle("Start at login", isOn: loginBinding)
            if loginNeedsApproval {
                Button("Allow in System Settings…") { LaunchAtLogin.openSystemSettings() }
            }
            if let loginError {
                Text(loginError).foregroundStyle(.red)
            }
            Toggle("Switch to Dark Mode at sunset", isOn: $store.settings.darkModeSync)
            Toggle("Bedtime reminder", isOn: bedtimeReminder)
        }
    }

    // MARK: Bindings

    private func kelvinSlider(
        _ title: String, _ keyPath: WritableKeyPath<UserSettings, Double>, _ range: ClosedRange<Double>
    ) -> some View {
        let binding = Binding<Double>(
            get: { store.settings[keyPath: keyPath] },
            set: { value in
                store.settings[keyPath: keyPath] = value
                controller.preview(kelvin: value)
            })
        return LabeledContent(title) {
            HStack {
                Slider(value: binding, in: range, step: 100)
                Text("\(Int(binding.wrappedValue))K")
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }

    private var bedtimeBrightness: Binding<Double> {
        Binding(
            get: { store.settings.bedtimeBrightness },
            set: { value in
                store.settings.bedtimeBrightness = value
                controller.preview(bedtimeBrightness: value)
            })
    }

    private var wakeTime: Binding<Date> {
        Binding(
            get: { clockDate(store.settings.wakeMinutes) },
            set: { store.settings.wakeMinutes = minutesAfterMidnight($0) })
    }

    private func weekdayWakeRow(_ weekday: Int) -> some View {
        let overridden = store.settings.wakeMinutesByWeekday[weekday] != nil
        return LabeledContent(Calendar.current.weekdaySymbols[weekday - 1]) {
            HStack {
                if overridden {
                    Button {
                        store.settings.wakeMinutesByWeekday[weekday] = nil
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("Use the default wake time")
                } else {
                    Text("Default").foregroundStyle(.secondary)
                }
                DatePicker("", selection: weekdayWakeTime(weekday), displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
    }

    /// Calendar weekdays (1 = Sunday) starting from the user's first weekday.
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    /// Bedtime before tomorrow's wake time.
    private var tonightsBedtime: Int {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let weekday = Calendar.current.component(.weekday, from: tomorrow)
        return store.settings.bedtimeMinutes(forWake: store.settings.wakeMinutes(onWeekday: weekday))
    }

    /// Picking the default time clears that day's override.
    private func weekdayWakeTime(_ weekday: Int) -> Binding<Date> {
        Binding(
            get: { clockDate(store.settings.wakeMinutes(onWeekday: weekday)) },
            set: { date in
                let minutes = minutesAfterMidnight(date)
                store.settings.wakeMinutesByWeekday[weekday] = minutes == store.settings.wakeMinutes ? nil : minutes
            })
    }

    private func clockDate(_ minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private func minutesAfterMidnight(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
    }

    private var manualLocation: Binding<Bool> {
        Binding(
            get: { store.settings.manualTimeZone != nil },
            set: { manual in
                let zones = controller.timeZoneIdentifiers
                let current = TimeZone.current.identifier
                store.settings.manualTimeZone = manual
                    ? (zones.contains(current) ? current : zones.first)
                    : nil
            })
    }

    private var zonesByRegion: [(region: String, zones: [String])] {
        Dictionary(grouping: controller.timeZoneIdentifiers, by: ZoneTab.regionName(for:))
            .map { ($0.key, $0.value.sorted { zoneLabel($0, inRegion: true) < zoneLabel($1, inRegion: true) }) }
            .sorted { $0.region < $1.region }
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                do {
                    try LaunchAtLogin.set(enabled)
                    loginError = nil
                } catch {
                    loginError = error.localizedDescription
                }
                launchAtLogin = LaunchAtLogin.isEnabled
                loginNeedsApproval = LaunchAtLogin.needsApproval
            })
    }

    private var bedtimeReminder: Binding<Bool> {
        Binding(
            get: { store.settings.bedtimeReminder },
            set: { enabled in
                store.settings.bedtimeReminder = enabled
                if enabled { controller.notifier.requestAuthorization() }
            })
    }

    // MARK: Formatting

    private func duration(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    private func clock(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date())
        return date?.formatted(date: .omitted, time: .shortened) ?? ""
    }

    private func describe(_ resolved: ResolvedLocation) -> String {
        switch resolved.source {
        case .manual(let id): return "Manual: \(zoneLabel(id))"
        case .coreLocation: return "Location Services (\(zoneLabel(TimeZone.current.identifier)))"
        case .timeZone(let id): return zoneLabel(id)
        case .unknown: return "Estimate from UTC offset (\(zoneLabel(TimeZone.current.identifier)))"
        }
    }

    private func zoneLabel(_ id: String, inRegion: Bool = false) -> String {
        ZoneTab.displayName(for: id, inRegion: inRegion)
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: "")
    }
}

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    private let controller: TintController

    init(controller: TintController) {
        self.controller = controller
    }

    func show() {
        controller.settingsOpenedAt = Date()
        if window == nil {
            let view = PreferencesView(store: controller.store, controller: controller)
            let window = SettingsWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "SolarDial Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

/// Escape follows the responder chain, allowing controls and sheets to cancel first.
@MainActor
private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        guard attachedSheet == nil else {
            super.cancelOperation(sender)
            return
        }
        performClose(sender)
    }
}
