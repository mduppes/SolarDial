import Foundation

/// Switches macOS between light and dark appearance when the schedule crosses sunset or sunrise.
/// Edge-triggered: if the user changes the appearance by hand, it stays until the next crossing.
/// Goes through System Events, so macOS asks once for Automation permission.
@MainActor
final class AppearanceSync {
    private var lastDesired: Bool?

    func update(prefersDark: Bool, enabled: Bool) {
        guard enabled else {
            lastDesired = nil
            return
        }
        guard prefersDark != lastDesired else { return }
        lastDesired = prefersDark
        guard prefersDark != Self.isDark else { return }
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(prefersDark)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private static var isDark: Bool {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    }
}
