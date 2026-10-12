import AppKit
import FluxCore

@MainActor
final class StatusItemManager: NSObject, NSMenuDelegate {
    private let controller: TintController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let timeFormat: Date.FormatStyle = .dateTime.hour().minute()

    init(controller: TintController) {
        self.controller = controller
        super.init()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        updateIcon()
    }

    func updateIcon() {
        let symbol: String
        if controller.temporaryDisable != nil || controller.isFrontAppDisabled {
            symbol = "sun.max.trianglebadge.exclamationmark"
        } else {
            switch controller.schedule?.phase {
            case .bedtime: symbol = "moon.stars"
            case .sunset: symbol = "moon"
            case .transition: symbol = "sun.horizon"
            case .day, nil: symbol = "sun.max"
            }
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Flux")
        image?.isTemplate = true
        item.button?.image = image
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for line in statusLines() {
            let info = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())

        if controller.temporaryDisable != nil {
            menu.addItem(action("Resume", #selector(resume)))
        } else {
            menu.addItem(action("Disable for an Hour", #selector(disableForAnHour)))
            menu.addItem(action("Disable Until Sunrise", #selector(disableUntilSunrise)))
        }
        if let app = controller.frontApp, app.bundleIdentifier != nil {
            let name = app.localizedName ?? app.bundleIdentifier ?? "App"
            let toggle = action("Disable for \(name)", #selector(toggleFrontApp))
            toggle.state = controller.isFrontAppDisabled ? .on : .off
            menu.addItem(toggle)
        }
        let fullscreen = action("Disable for Full-Screen Apps", #selector(toggleFullscreen))
        fullscreen.state = controller.store.settings.disableForFullscreen ? .on : .off
        menu.addItem(fullscreen)

        menu.addItem(.separator())
        menu.addItem(action("Quit Flux", #selector(quit), key: "q"))
    }

    private func statusLines() -> [String] {
        var lines: [String] = []
        if let disable = controller.temporaryDisable {
            lines.append("Paused until \(disable.endDate.formatted(timeFormat))")
        } else if controller.isFrontAppDisabled, let name = controller.frontApp?.localizedName {
            lines.append("Paused for \(name)")
        } else if let schedule = controller.schedule {
            lines.append("\(Int(schedule.kelvin.rounded()))K · \(phaseName(schedule.phase))")
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

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func resume() { controller.resume() }
    @objc private func disableForAnHour() { controller.disableForAnHour() }
    @objc private func disableUntilSunrise() { controller.disableUntilSunrise() }
    @objc private func toggleFrontApp() { controller.toggleFrontAppDisabled() }
    @objc private func toggleFullscreen() { controller.toggleFullscreenDisable() }
    @objc private func quit() { NSApp.terminate(nil) }
}
