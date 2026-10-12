import AppKit
import CoreGraphics
import FluxCore

/// Owns every write to display gamma. Keeps each display's calibrated base table so tinting only
/// moves the white point, and fades between targets.
@MainActor
final class DisplayManager {
    var onDisplaysChanged: (() -> Void)?

    private var baseTables: [CGDirectDisplayID: GammaTable] = [:]
    private var applied: [CGDirectDisplayID: DisplayTarget] = [:]
    private var fades: [CGDirectDisplayID: TargetFade] = [:]
    private var fadeTimer: Timer?
    private var pendingReset: DispatchWorkItem?

    init() {
        CGDisplayRestoreColorSyncSettings()
        captureBaseTables()
        CGDisplayRegisterReconfigurationCallback(displayReconfigured, nil)
        NotificationCenter.default.addObserver(
            forName: .fluxDisplaysReconfigured, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleReset() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleReset() }
            }
        }
    }

    func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// Moves each display towards its target over `fadeDuration` seconds.
    func setTargets(_ targets: [CGDirectDisplayID: DisplayTarget], fadeDuration: TimeInterval) {
        let now = Date()
        for (id, target) in targets {
            if let fade = fades[id], !fade.to.needsChange(to: target) { continue }
            let current = fades[id]?.current(at: now) ?? applied[id] ?? .neutral
            if fades[id] == nil, !current.needsChange(to: target) {
                if applied[id] == nil { apply(target, to: id) }
                continue
            }
            if fadeDuration <= 0 {
                fades[id] = nil
                apply(target, to: id)
            } else {
                fades[id] = TargetFade(from: current, to: target, start: now, duration: fadeDuration)
            }
        }
        if !fades.isEmpty { startFadeTimer() }
    }

    func restore() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        fades.removeAll()
        applied.removeAll()
        CGDisplayRestoreColorSyncSettings()
    }

    private func apply(_ target: DisplayTarget, to id: CGDirectDisplayID) {
        write(target.table(base: base(for: id)), to: id)
        applied[id] = target
    }

    private func write(_ table: GammaTable, to id: CGDirectDisplayID) {
        CGSetDisplayTransferByTable(id, UInt32(table.count), table.red, table.green, table.blue)
    }

    private func base(for id: CGDirectDisplayID) -> GammaTable {
        if let table = baseTables[id] { return table }
        let table = captureBaseTable(for: id)
        baseTables[id] = table
        return table
    }

    private func startFadeTimer() {
        guard fadeTimer == nil else { return }
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.stepFades() }
        }
    }

    private func stepFades() {
        let now = Date()
        for (id, fade) in fades {
            if fade.isFinished(at: now) {
                fades[id] = nil
                apply(fade.to, to: id)
            } else {
                write(fade.table(at: now, base: base(for: id)), to: id)
                applied[id] = fade.current(at: now)
            }
        }
        if fades.isEmpty {
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    /// Displays come back from sleep or reconfiguration with their gamma reset, sometimes in
    /// several steps, so wait for things to settle, then recapture the base tables and reapply.
    private func scheduleReset() {
        pendingReset?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.resetAfterReconfiguration() }
        }
        pendingReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: work)
    }

    private func resetAfterReconfiguration() {
        let targets = applied.merging(fades.mapValues(\.to)) { _, fadeTarget in fadeTarget }
        fades.removeAll()
        applied.removeAll()
        CGDisplayRestoreColorSyncSettings()
        captureBaseTables()
        for (id, target) in targets where baseTables[id] != nil {
            apply(target, to: id)
        }
        onDisplaysChanged?()
    }

    private func captureBaseTables() {
        baseTables.removeAll()
        for id in activeDisplays() {
            baseTables[id] = captureBaseTable(for: id)
        }
    }

    private func captureBaseTable(for id: CGDirectDisplayID) -> GammaTable {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity > 0 else { return .identity(count: 256) }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &count) == .success, count > 1
        else { return .identity(count: 256) }
        let n = Int(count)
        return GammaTable(red: Array(red.prefix(n)), green: Array(green.prefix(n)), blue: Array(blue.prefix(n)))
    }
}

extension Notification.Name {
    static let fluxDisplaysReconfigured = Notification.Name("FluxDisplaysReconfigured")
}

private func displayReconfigured(
    _ display: CGDirectDisplayID, _ flags: CGDisplayChangeSummaryFlags, _ userInfo: UnsafeMutableRawPointer?
) {
    guard !flags.contains(.beginConfigurationFlag) else { return }
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .fluxDisplaysReconfigured, object: nil)
    }
}
