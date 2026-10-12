import Foundation
import FluxCore

@MainActor
final class SettingsStore {
    private let defaults: UserDefaults
    private static let key = "settings"

    var settings: UserSettings {
        didSet { defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(UserSettings.self, from: $0) } ?? UserSettings()
    }
}
