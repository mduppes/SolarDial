import Foundation
import FluxCore
import Observation

@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let key = "settings"

    var settings: UserSettings {
        didSet {
            guard settings != oldValue else { return }
            defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
            onChange?()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(UserSettings.self, from: $0) } ?? UserSettings()
    }
}
