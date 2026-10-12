import Foundation

/// What one display should show.
public enum DisplayTarget: Equatable, Sendable {
    /// White point at this colour temperature; `ColorTemperature.neutral` means untinted.
    case kelvin(Double)
    /// Red only, with luminance inverted, for preserving night vision.
    case darkroom

    public static let neutral = DisplayTarget.kelvin(ColorTemperature.neutral)

    public func table(base: GammaTable) -> GammaTable {
        switch self {
        case .kelvin(let kelvin):
            return base.tinted(kelvin: kelvin)
        case .darkroom:
            let zero = [Float](repeating: 0, count: base.count)
            return GammaTable(red: base.red.reversed(), green: zero, blue: zero)
        }
    }

    /// Whether moving from `self` to `other` needs any change on screen.
    public func needsChange(to other: DisplayTarget) -> Bool {
        switch (self, other) {
        case (.kelvin(let a), .kelvin(let b)): abs(a - b) >= 1
        case (.darkroom, .darkroom): false
        default: true
        }
    }
}

/// A timed transition between two targets. Kelvin-to-Kelvin fades go through mired space;
/// anything involving darkroom cross-fades the tables.
public struct TargetFade: Equatable, Sendable {
    public let from: DisplayTarget
    public let to: DisplayTarget
    public let start: Date
    public let duration: TimeInterval

    public init(from: DisplayTarget, to: DisplayTarget, start: Date, duration: TimeInterval) {
        self.from = from
        self.to = to
        self.start = start
        self.duration = duration
    }

    public func progress(at date: Date) -> Double {
        guard duration > 0 else { return 1 }
        let t = (date.timeIntervalSince(start) / duration).clamped(to: 0...1)
        return t * t * (3 - 2 * t)
    }

    public func isFinished(at date: Date) -> Bool {
        date.timeIntervalSince(start) >= duration
    }

    public func table(at date: Date, base: GammaTable) -> GammaTable {
        let t = progress(at: date)
        if case .kelvin(let a) = from, case .kelvin(let b) = to {
            return base.tinted(kelvin: ColorTemperature.blend(a, b, fraction: t))
        }
        return from.table(base: base).mixed(with: to.table(base: base), fraction: t)
    }

    /// Where the fade currently is, for starting a new fade from here.
    public func current(at date: Date) -> DisplayTarget {
        let t = progress(at: date)
        if case .kelvin(let a) = from, case .kelvin(let b) = to {
            return .kelvin(ColorTemperature.blend(a, b, fraction: t))
        }
        return t < 0.5 ? from : to
    }
}