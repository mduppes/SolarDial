import AppKit
import CoreGraphics
import FluxCore

/// Owns every write to display gamma. Keeps each display's calibrated base table so tinting only
/// moves the white point, fades between targets, and notices when another app overwrites them.
@MainActor
final class DisplayManager {
    var onDisplaysChanged: (() -> Void)?

    private var baseTables: [CGDirectDisplayID: GammaTable] = [:]
    private var applied: [CGDirectDisplayID: DisplayTarget] = [:]
    private var written: [CGDirectDisplayID: GammaTable] = [:]
    private var fades: [CGDirectDisplayID: TargetFade] = [:]
    private var fadeTimer: Timer?
    private var pendingReset: DispatchWorkItem?
    /// The system resets gamma around wake and reconfiguration; don't mistake that for another app.
    private var settledAfter = Date().addingTimeInterval(5)

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
        written.removeAll()
        CGDisplayRestoreColorSyncSettings()
    }

    /// Re-reads each display's table and compares it with what was last written. Rewrites any
    /// display that differs and returns true, meaning some other app is changing display colour.
    func checkForOverwrites() -> Bool {
        guard fades.isEmpty, pendingReset == nil, Date() > settledAfter else { return false }
        var overwritten = false
        for (id, table) in written {
            guard let current = readTable(id), !current.approximatelyEquals(table) else { continue }
            overwritten = true
            write(table, to: id)
        }
        return overwritten
    }

    private func apply(_ target: DisplayTarget, to id: CGDirectDisplayID) {
        write(target.table(base: base(for: id)), to: id)
        applied[id] = target
    }

    private func write(_ table: GammaTable, to id: CGDirectDisplayID) {
        if CGSetDisplayTransferByTable(id, UInt32(table.count), table.red, table.green, table.blue) == .success {
            written[id] = table
        }
    }

    private func base(for id: CGDirectDisplayID) -> GammaTable {
        if let table = baseTables[id] { return table }
        let table = readTable(id) ?? .identity(count: 256)
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
                apply(fade.current(at: now), to: id)
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
        pendingReset = nil
        settledAfter = Date().addingTimeInterval(5)
        let targets = applied.merging(fades.mapValues(\.to)) { _, fadeTarget in fadeTarget }
        fades.removeAll()
        applied.removeAll()
        written.removeAll()
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
            baseTables[id] = readTable(id) ?? .identity(count: 256)
        }
    }

    private func readTable(_ id: CGDirectDisplayID) -> GammaTable? {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity > 0 else { return nil }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &count) == .success, count > 1
        else { return nil }
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
