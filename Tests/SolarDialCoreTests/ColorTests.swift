import Foundation
import Testing
@testable import SolarDialCore

struct ColorTemperatureTests {
    @Test func neutralIsWhite() {
        let rgb = ColorTemperature.multipliers(kelvin: ColorTemperature.neutral)
        #expect(abs(rgb.red - 1) < 1e-9)
        #expect(abs(rgb.green - 1) < 1e-9)
        #expect(abs(rgb.blue - 1) < 1e-9)
    }

    @Test(arguments: [1200.0, 1900, 2300, 2700, 3400, 4200, 5000])
    func warmTemperaturesKeepRedAndCutBlue(kelvin: Double) {
        let rgb = ColorTemperature.multipliers(kelvin: kelvin)
        #expect(rgb.red == 1)
        #expect(rgb.green < 1)
        #expect(rgb.blue < rgb.green)
    }

    @Test func blueFallsMonotonicallyAsItGetsWarmer() {
        let blues = stride(from: 6500.0, through: 1200, by: -100).map {
            ColorTemperature.multipliers(kelvin: $0).blue
        }
        #expect(zip(blues, blues.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test func coolTemperaturesCutRed() {
        let rgb = ColorTemperature.multipliers(kelvin: 9000)
        #expect(rgb.blue == 1)
        #expect(rgb.red < 1)
    }

    @Test func blendIsInMiredSpace() {
        #expect(ColorTemperature.blend(6500, 3400, fraction: 0) == 6500)
        #expect(abs(ColorTemperature.blend(6500, 3400, fraction: 1) - 3400) < 1e-9)
        let mid = ColorTemperature.blend(6000, 3000, fraction: 0.5)
        #expect(abs(mid - 4000) < 1e-9)
    }
}

struct GammaTableTests {
    @Test func identityRamp() {
        let table = GammaTable.identity(count: 256)
        #expect(table.count == 256)
        #expect(table.red.first == 0)
        #expect(table.red.last == 1)
    }

    @Test func neutralTintLeavesTableUnchanged() {
        let base = GammaTable(red: [0, 0.4, 0.9], green: [0, 0.5, 1], blue: [0, 0.45, 0.95])
        #expect(base.tinted(kelvin: 6500) == base)
    }

    @Test func approximateEqualityAcrossSizes() {
        let small = GammaTable.identity(count: 256).tinted(kelvin: 3400)
        let large = GammaTable.identity(count: 1024).tinted(kelvin: 3400)
        #expect(small.approximatelyEquals(large))
        #expect(!small.approximatelyEquals(GammaTable.identity(count: 1024)))
    }

    @Test func tintScalesEachChannel() {
        let base = GammaTable.identity(count: 3)
        let tinted = base.scaled(by: RGB(red: 1, green: 0.5, blue: 0.25))
        #expect(tinted.green == [0, 0.25, 0.5])
        #expect(tinted.blue == [0, 0.125, 0.25])
    }
}
