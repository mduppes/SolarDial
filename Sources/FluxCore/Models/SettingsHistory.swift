import Foundation

/// Undo stack for settings. Changes arriving in quick succession (a slider drag) collapse into
/// one step, so a single undo returns to where the drag started.
public struct SettingsHistory: Sendable {
    public static let coalesceInterval: TimeInterval = 1
    public static let limit = 50

    private var steps: [UserSettings] = []
    private var lastRecorded: Date?

    public init() {}

    public var canUndo: Bool { !steps.isEmpty }

    /// Call with the value from *before* a change.
    public mutating func record(_ previous: UserSettings, at date: Date) {
        defer { lastRecorded = date }
        if let lastRecorded, date.timeIntervalSince(lastRecorded) < Self.coalesceInterval, !steps.isEmpty { return }
        steps.append(previous)
        if steps.count > Self.limit { steps.removeFirst() }
    }

    public mutating func undo() -> UserSettings? {
        lastRecorded = nil
        return steps.popLast()
    }
}
