import Foundation

/// A display transfer table: one output value (0...1) per input step, per channel.
public struct GammaTable: Equatable, Sendable {
    public var red: [Float]
    public var green: [Float]
    public var blue: [Float]

    public init(red: [Float], green: [Float], blue: [Float]) {
        precondition(red.count == green.count && green.count == blue.count, "channel sizes differ")
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var count: Int { red.count }

    public static func identity(count: Int) -> GammaTable {
        let ramp = (0..<count).map { Float($0) / Float(max(1, count - 1)) }
        return GammaTable(red: ramp, green: ramp, blue: ramp)
    }

    /// This table with each channel's output scaled. Used on a display's calibrated base table,
    /// so calibration is preserved and only the white point moves.
    public func scaled(by rgb: RGB) -> GammaTable {
        GammaTable(
            red: red.map { $0 * Float(rgb.red) },
            green: green.map { $0 * Float(rgb.green) },
            blue: blue.map { $0 * Float(rgb.blue) })
    }

    /// Linear blend towards `other` (same size), `fraction` 0 = self, 1 = other.
    public func mixed(with other: GammaTable, fraction: Double) -> GammaTable {
        let t = Float(fraction.clamped(to: 0...1))
        func mix(_ a: [Float], _ b: [Float]) -> [Float] { zip(a, b).map { $0 + ($1 - $0) * t } }
        return GammaTable(red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue))
    }

    /// Compares sampled entries (tables may have different lengths) within `tolerance`.
    /// Used to notice another app overwriting what we wrote.
    public func approximatelyEquals(_ other: GammaTable, tolerance: Float = 0.01, samples: Int = 17) -> Bool {
        guard count > 1, other.count > 1 else { return count == other.count }
        for s in 0..<samples {
            let f = Double(s) / Double(samples - 1)
            let i = Int((f * Double(count - 1)).rounded())
            let j = Int((f * Double(other.count - 1)).rounded())
            if abs(red[i] - other.red[j]) > tolerance
                || abs(green[i] - other.green[j]) > tolerance
                || abs(blue[i] - other.blue[j]) > tolerance { return false }
        }
        return true
    }

    public func tinted(kelvin: Double) -> GammaTable {
        scaled(by: ColorTemperature.multipliers(kelvin: kelvin))
    }
}
