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

    public func tinted(kelvin: Double) -> GammaTable {
        scaled(by: ColorTemperature.multipliers(kelvin: kelvin))
    }
}
