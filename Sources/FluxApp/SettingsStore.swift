import Foundation
import FluxCore
import Observation

@MainActor
@Observable
final class SettingsStore {
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private static let key = "settings"
    @ObservationIgnored private var restoring = false

    private(set) var history = SettingsHistory()

    var settings: UserSettings {
        didSet {
            guard settings != oldValue else { return }
            if !restoring { history.record(oldValue, at: Date()) }
            defaults.set(try? JSONEncoder().encode(settings), forKey: Self.key)
            onChange?()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(UserSettings.self, from: $0) } ?? UserSettings()
    }

    var canUndo: Bool { history.canUndo }

    func undo() {
        guard let previous = history.undo() else { return }
        restoring = true
        settings = previous
        restoring = false
    }

    /// Factory settings. Undoable.
    func resetToDefaults() {
        settings = UserSettings()
    }
}
