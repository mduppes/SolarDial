import AppKit
import FluxCore

@MainActor
final class StatusItemManager: NSObject, NSMenuDelegate {
    private let controller: TintController
    private let preferences: PreferencesWindowController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var currentSymbol: String?
    private let timeFormat: Date.FormatStyle = .dateTime.hour().minute()

    init(controller: TintController) {
        self.controller = controller
        preferences = PreferencesWindowController(controller: controller)
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        updateIcon()
    }

    func updateIcon() {
        let symbol: String
        if controller.conflict != nil {
            symbol = "exclamationmark.triangle"
        } else if controller.temporaryDisable != nil || controller.isFrontAppDisabled {
            symbol = "sun.max.trianglebadge.exclamationmark"
        } else if controller.movieMode != nil {
            symbol = "film"
        } else {
            symbol = "sun.horizon"
        }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Flux")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        guard symbol != currentSymbol else { return }
        currentSymbol = symbol
        item.button?.image = image
        // variableLength adds 8 pt per side. Setting length re-lays out the menu bar, so only on change.
        let width = (image?.size.width ?? 18).rounded(.up)
        if item.length != width { item.length = width }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for line in statusLines() {
            let info = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())

        menu.addItem(toggle("Disable for an Hour", #selector(toggleHour), on: controller.isDisabledForAnHour))
        menu.addItem(toggle("Disable Until Sunrise", #selector(toggleSunrise), on: controller.isDisabledUntilSunrise))
        if let app = controller.frontApp, let id = app.bundleIdentifier {
            let name = app.localizedName ?? id
            menu.addItem(toggle("Disable for \(name)", #selector(toggleFrontApp), on: controller.isFrontAppDisabled))
        }
        menu.addItem(toggle(
            "Disable for Full-Screen Apps", #selector(toggleFullscreen),
            on: controller.store.settings.disableForFullscreen))
        menu.addItem(.separator())
        menu.addItem(toggle("Movie Mode", #selector(toggleMovie), on: controller.movieMode != nil))

        menu.addItem(.separator())
        menu.addItem(action("Settings…", #selector(showPreferences), key: ","))
        menu.addItem(action("Quit Flux", #selector(quit), key: "q"))
    }

    private func statusLines() -> [String] {
        var lines: [String] = []
        if let warning = controller.conflictMessage {
            lines.append("⚠︎ \(warning)")
        }
        if let disable = controller.temporaryDisable {
            lines.append("Disabled until \(disable.endDate.formatted(timeFormat))")
        } else if controller.isFrontAppDisabled, let name = controller.frontApp?.localizedName {
            lines.append("Disabled for \(name)")
        } else if let movie = controller.movieMode {
            lines.append("\(Int(controller.store.settings.movieKelvin))K · Movie mode until \(movie.until.formatted(timeFormat))")
        } else if let schedule = controller.schedule {
            var line = "\(Int(schedule.kelvin.rounded()))K · \(phaseName(schedule.phase))"
            if schedule.brightness < 0.995 { line += " · \(Int((schedule.brightness * 100).rounded()))% brightness" }
            lines.append(line)
        }
        let count = controller.fullscreenDisplays.count
        if count > 0, controller.temporaryDisable == nil, !controller.isFrontAppDisabled {
            lines.append(count == 1 ? "Full screen: 1 display untinted" : "Full screen: \(count) displays untinted")
        }
        if let schedule = controller.schedule, let rise = schedule.sunrise, let set = schedule.sunset {
            lines.append("Sunrise \(rise.formatted(timeFormat)) · Sunset \(set.formatted(timeFormat))")
        }
        if let location = controller.resolvedLocation {
            lines.append("Location: \(sourceName(location.source))")
        }
        return lines
    }

    private func phaseName(_ phase: Phase) -> String {
        switch phase {
        case .day: "Daytime"
        case .sunset: "Sunset"
        case .bedtime: "Bedtime"
        case .transition: "Transitioning"
        }
    }

    private func sourceName(_ source: LocationSource) -> String {
        switch source {
        case .manual: "Manual"
        case .coreLocation: "Location Services"
        case .timeZone(let id): "Time zone (\(id))"
        case .unknown: "Estimated from UTC offset"
        }
    }

    private func toggle(_ title: String, _ selector: Selector, on: Bool) -> NSMenuItem {
        let item = action(title, selector)
        item.state = on ? .on : .off
        return item
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleHour() { controller.toggleDisableForAnHour() }
    @objc private func toggleSunrise() { controller.toggleDisableUntilSunrise() }
    @objc private func toggleFrontApp() { controller.toggleFrontAppDisabled() }
    @objc private func toggleFullscreen() { controller.toggleFullscreenDisable() }
    @objc private func toggleMovie() { controller.toggleMovieMode() }
    @objc private func showPreferences() {
        // Activating while the menu is still dismissing leaves the menu-bar highlight on a neighbour.
        DispatchQueue.main.async { [preferences] in preferences.show() }
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
