import Foundation

/// A timed transition between two temperatures, interpolated in mired space.
public struct KelvinFade: Equatable, Sendable {
    public let from: Double
    public let to: Double
    public let start: Date
    public let duration: TimeInterval

    public init(from: Double, to: Double, start: Date, duration: TimeInterval) {
        self.from = from
        self.to = to
        self.start = start
        self.duration = duration
    }

    public func value(at date: Date) -> Double {
        guard duration > 0 else { return to }
        let t = date.timeIntervalSince(start) / duration
        let eased = t.clamped(to: 0...1)
        return ColorTemperature.blend(from, to, fraction: eased * eased * (3 - 2 * eased))
    }

    public func isFinished(at date: Date) -> Bool {
        date.timeIntervalSince(start) >= duration
    }
}
