import Foundation

/// What one display should show: a white point and a brightness scale.
public struct DisplayTarget: Equatable, Sendable {
    public var kelvin: Double
    /// Multiplies every channel's output, 0...1. Dims through the gamma table, not the backlight.
    public var brightness: Double

    public init(kelvin: Double, brightness: Double = 1) {
        self.kelvin = kelvin
        self.brightness = brightness
    }

    public static let neutral = DisplayTarget(kelvin: ColorTemperature.neutral)

    public func table(base: GammaTable) -> GammaTable {
        var rgb = ColorTemperature.multipliers(kelvin: kelvin)
        let b = brightness.clamped(to: 0...1)
        rgb.red *= b
        rgb.green *= b
        rgb.blue *= b
        return base.scaled(by: rgb)
    }

    /// Whether moving from `self` to `other` needs any change on screen.
    public func needsChange(to other: DisplayTarget) -> Bool {
        abs(kelvin - other.kelvin) >= 1 || abs(brightness - other.brightness) >= 0.002
    }

    /// Kelvin interpolated in mired space, brightness linearly.
    public static func blend(_ from: DisplayTarget, _ to: DisplayTarget, fraction: Double) -> DisplayTarget {
        let t = fraction.clamped(to: 0...1)
        return DisplayTarget(
            kelvin: ColorTemperature.blend(from.kelvin, to.kelvin, fraction: t),
            brightness: from.brightness + (to.brightness - from.brightness) * t)
    }
}

/// A timed, eased transition between two targets.
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

    public func isFinished(at date: Date) -> Bool {
        date.timeIntervalSince(start) >= duration
    }

    public func current(at date: Date) -> DisplayTarget {
        guard duration > 0 else { return to }
        let t = (date.timeIntervalSince(start) / duration).clamped(to: 0...1)
        return DisplayTarget.blend(from, to, fraction: t * t * (3 - 2 * t))
    }
}
