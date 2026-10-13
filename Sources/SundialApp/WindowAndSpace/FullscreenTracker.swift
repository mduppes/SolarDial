import AppKit
import CoreGraphics
import SundialCore

/// Finds displays whose visible top window fills the screen, and reports when that might have
/// changed (app switch or Space change). Uses only window bounds and layers, which don't need the
/// Screen Recording permission.
@MainActor
final class FullscreenTracker {
    var onChange: (() -> Void)?

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]
        for name in names {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.changed() }
            }
        }
    }

    func fullscreenDisplays(among ids: [CGDirectDisplayID]) -> Set<CGDirectDisplayID> {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let windows: [FullscreenGeometry.Window] = info.compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict)
            else { return nil }
            if let alpha = entry[kCGWindowAlpha as String] as? Double, alpha <= 0 { return nil }
            return FullscreenGeometry.Window(bounds: bounds, layer: layer)
        }
        let insets = notchInsets()
        let displays = ids.map {
            FullscreenGeometry.Display(id: $0, bounds: CGDisplayBounds($0), topInset: insets[$0] ?? 0)
        }
        let layers: Set<Int> = [0, Int(CGShieldingWindowLevel())]
        return FullscreenGeometry.fullscreenDisplays(windows: windows, displays: displays, eligibleLayers: layers)
    }

    /// Space switches animate, so check again once the new windows have settled.
    private func changed() {
        onChange?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    private func notchInsets() -> [CGDirectDisplayID: CGFloat] {
        var result: [CGDirectDisplayID: CGFloat] = [:]
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            result[number.uint32Value] = screen.safeAreaInsets.top
        }
        return result
    }
}
