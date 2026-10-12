import Foundation

/// Per-channel multipliers in display-encoded (gamma) space, each in 0...1.
public struct RGB: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let white = RGB(red: 1, green: 1, blue: 1)
}

public enum ColorTemperature {
    /// The temperature treated as "no tint". Maps exactly to `RGB.white`.
    public static let neutral: Double = 6500
    public static let range: ClosedRange<Double> = 1000...10_000

    /// White-point multipliers for a blackbody at `kelvin`, relative to `neutral`.
    public static func multipliers(kelvin: Double) -> RGB {
        let target = linearRGB(kelvin: kelvin.clamped(to: range))
        let reference = linearRGB(kelvin: neutral)
        var r = max(0, target.red / reference.red)
        var g = max(0, target.green / reference.green)
        var b = max(0, target.blue / reference.blue)
        let peak = max(r, g, b)
        r /= peak
        g /= peak
        b /= peak
        return RGB(red: encode(r), green: encode(g), blue: encode(b))
    }

    /// Interpolate in mired (1e6 / K) space, which tracks perceived colour change far better than Kelvin.
    public static func blend(_ from: Double, _ to: Double, fraction: Double) -> Double {
        let t = fraction.clamped(to: 0...1)
        let mired = 1e6 / from + (1e6 / to - 1e6 / from) * t
        return 1e6 / mired
    }

    /// Linear-light sRGB of the Planckian locus (Krystek 1985 approximation, valid 1000–15000 K), Y = 1.
    static func linearRGB(kelvin t: Double) -> RGB {
        let u = (0.860117757 + 1.54118254e-4 * t + 1.28641212e-7 * t * t)
            / (1 + 8.42420235e-4 * t + 7.08145163e-7 * t * t)
        let v = (0.317398726 + 4.22806245e-5 * t + 4.20481691e-8 * t * t)
            / (1 - 2.89741816e-5 * t + 1.61456053e-7 * t * t)
        let d = 2 * u - 8 * v + 4
        let x = 3 * u / d
        let y = 2 * v / d
        let bigX = x / y
        let bigZ = (1 - x - y) / y
        return RGB(
            red: 3.2406 * bigX - 1.5372 - 0.4986 * bigZ,
            green: -0.9689 * bigX + 1.8758 + 0.0415 * bigZ,
            blue: 0.0557 * bigX - 0.2040 + 1.0570 * bigZ)
    }

    static func encode(_ linear: Double) -> Double {
        if linear >= 1 { return 1 }
        return linear <= 0.0031308 ? 12.92 * linear : 1.055 * pow(linear, 1 / 2.4) - 0.055
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
