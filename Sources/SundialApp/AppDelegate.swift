import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: TintController?
    private var statusItem: StatusItemManager?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        migrateLegacyPreferences()
        let controller = TintController(
            store: SettingsStore(),
            displays: DisplayManager(),
            fullscreen: FullscreenTracker(),
            location: LocationProvider())
        let statusItem = StatusItemManager(controller: controller)
        controller.onUpdate = { [weak statusItem] in statusItem?.updateIcon() }
        self.controller = controller
        self.statusItem = statusItem
        installSignalHandlers()
        controller.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.showPreferences()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    /// Keep the clone's existing preferences when switching to the Sundial bundle ID.
    private func migrateLegacyPreferences() {
        guard Bundle.main.bundleIdentifier == "com.mduppes.sundial" else { return }
        let defaults = UserDefaults.standard
        guard let legacy = defaults.persistentDomain(forName: "com.mduppes.flux") else { return }
        for key in ["settings", "lastLocationFix"] where defaults.object(forKey: key) == nil {
            if let value = legacy[key] { defaults.set(value, forKey: key) }
        }
    }

    /// Route termination signals through the normal quit path so gamma is restored.
    /// (On a crash, macOS restores the ColorSync settings itself when the process exits.)
    private func installSignalHandlers() {
        for sig in [SIGINT, SIGTERM, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated { NSApp.terminate(nil) }
            }
            source.resume()
            signalSources.append(source)
        }
    }
}
