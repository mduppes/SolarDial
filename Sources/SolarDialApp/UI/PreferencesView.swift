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
            Stepper(value: $store.settings.sleepMinutes, in: 300...720, step: 30) {
                LabeledContent("Sleep length", value: duration(store.settings.sleepMinutes))
            }
            LabeledContent("Bedtime", value: clock(store.settings.bedtimeMinutes))
            Picker("Transition speed", selection: $store.settings.transitionMinutes) {
                Text("Fast (20 minutes)").tag(20)
                Text("Slow (60 minutes)").tag(60)
            }
        }
    }

    private var locationSection: some View {
        Section {
            Toggle("Set location manually", isOn: manualLocation)
            if let manual = store.settings.manualCoordinates {
                TextField("Latitude", value: coordinate(\.latitude, fallback: manual), format: .number)
                TextField("Longitude", value: coordinate(\.longitude, fallback: manual), format: .number)
            }
            if let resolved = controller.resolvedLocation {
                LabeledContent("Using", value: describe(resolved))
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Automatic location uses Location Services when allowed, otherwise your time zone. Nothing is sent over the network.")
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
            get: {
                let minutes = store.settings.wakeMinutes
                return Calendar.current.date(
                    bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.settings.wakeMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
            })
    }

    private var manualLocation: Binding<Bool> {
        Binding(
            get: { store.settings.manualCoordinates != nil },
            set: { manual in
                store.settings.manualCoordinates = manual
                    ? (controller.resolvedLocation?.coordinates ?? Coordinates(latitude: 0, longitude: 0))
                    : nil
            })
    }

    private func coordinate(_ keyPath: WritableKeyPath<Coordinates, Double>, fallback: Coordinates) -> Binding<Double> {
        Binding(
            get: { store.settings.manualCoordinates?[keyPath: keyPath] ?? fallback[keyPath: keyPath] },
            set: { value in
                var coordinates = store.settings.manualCoordinates ?? fallback
                coordinates[keyPath: keyPath] = value
                guard coordinates.isValid else { return }
                store.settings.manualCoordinates = coordinates
            })
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
        let c = resolved.coordinates
        let position = String(format: "%.2f, %.2f", c.latitude, c.longitude)
        switch resolved.source {
        case .manual: return "Manual (\(position))"
        case .coreLocation: return "Location Services (\(position))"
        case .timeZone(let id): return "Time zone \(id) (\(position))"
        case .unknown: return "UTC offset estimate (\(position))"
        }
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
