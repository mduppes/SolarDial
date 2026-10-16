import AppKit
import CoreLocation
import SolarDialCore

/// Supplies coordinates without ever showing UI beyond the system's one-time permission prompt.
/// A Core Location fix is remembered with the time zone it was taken in; after a time-zone
/// change the `zone.tab` entry is used until a fresh fix arrives.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    var onChange: (() -> Void)?

    private let manager = CLLocationManager()
    private let defaults: UserDefaults
    private let zoneTab: ZoneTab?
    private var lastFix: LocationFix?
    private static let fixKey = "lastLocationFix"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        zoneTab = (try? String(contentsOfFile: ZoneTab.systemPath, encoding: .utf8)).map(ZoneTab.init)
        if let data = defaults.data(forKey: Self.fixKey) {
            lastFix = try? JSONDecoder().decode(LocationFix.self, from: data)
        }
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer

        NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                NSTimeZone.resetSystemTimeZone()
                self?.onChange?()
                self?.refresh()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func resolve(manualTimeZone: String?) -> ResolvedLocation {
        LocationResolver.resolve(manualTimeZone: manualTimeZone, lastFix: lastFix, timeZone: .current, zoneTab: zoneTab)
    }

    /// Time zones that can be picked as a manual location.
    var timeZoneIdentifiers: [String] { zoneTab?.identifiers ?? [] }

    /// Asks Core Location for one fix. Only works from the bundled app, which declares a usage string.
    func refresh() {
        guard Bundle.main.object(forInfoDictionaryKey: "NSLocationUsageDescription") != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            if self.manager.authorizationStatus == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinates = Coordinates(
            latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        MainActor.assumeIsolated { self.store(coordinates) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func store(_ coordinates: Coordinates) {
        let fix = LocationFix(coordinates: coordinates, timeZoneIdentifier: TimeZone.current.identifier)
        guard fix != lastFix else { return }
        lastFix = fix
        defaults.set(try? JSONEncoder().encode(fix), forKey: Self.fixKey)
        onChange?()
    }
}
