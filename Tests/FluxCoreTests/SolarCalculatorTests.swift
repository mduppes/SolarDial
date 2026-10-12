import Foundation
import Testing
@testable import FluxCore

struct SolarCalculatorTests {
    let saoPaulo = Coordinates(latitude: -23.55, longitude: -46.63)
    let london = Coordinates(latitude: 51.5074, longitude: -0.1278)

    func date(_ string: String) -> Date {
        try! Date(string, strategy: .iso8601)
    }

    func minutesApart(_ a: Date?, _ b: Date) -> Double {
        abs(a!.timeIntervalSince(b)) / 60
    }

    // Reference times from timeanddate.com / sunrise-sunset.org.
    @Test func londonSummerSolstice() {
        let tz = TimeZone(identifier: "Europe/London")!
        let day = date("2026-06-21T12:00:00Z")
        let rise = SolarCalculator.time(of: .rise, on: day, coordinates: london, timeZone: tz)
        let set = SolarCalculator.time(of: .set, on: day, coordinates: london, timeZone: tz)
        #expect(minutesApart(rise, date("2026-06-21T03:43:00Z")) < 3)
        #expect(minutesApart(set, date("2026-06-21T20:21:00Z")) < 3)
    }

    @Test func saoPauloOctober() {
        let tz = TimeZone(identifier: "America/Sao_Paulo")!
        let day = date("2026-10-12T15:00:00Z")
        let rise = SolarCalculator.time(of: .rise, on: day, coordinates: saoPaulo, timeZone: tz)
        let set = SolarCalculator.time(of: .set, on: day, coordinates: saoPaulo, timeZone: tz)
        #expect(minutesApart(rise, date("2026-10-12T08:36:18Z")) < 2)
        #expect(minutesApart(set, date("2026-10-12T21:10:01Z")) < 2)
    }

    @Test func eventsFallOnTheRequestedLocalDay() {
        let tz = TimeZone(identifier: "Australia/Sydney")!
        let sydney = Coordinates(latitude: -33.87, longitude: 151.21)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 9))!
        let set = SolarCalculator.time(of: .set, on: day, coordinates: sydney, timeZone: tz)!
        let rise = SolarCalculator.time(of: .rise, on: day, coordinates: sydney, timeZone: tz)!
        #expect(calendar.isDate(set, inSameDayAs: day))
        #expect(calendar.isDate(rise, inSameDayAs: day))
        #expect(rise < set)
    }

    @Test func polarNightHasNoSunrise() {
        let tromso = Coordinates(latitude: 69.65, longitude: 18.96)
        let tz = TimeZone(identifier: "Europe/Oslo")!
        let day = date("2026-12-21T12:00:00Z")
        #expect(SolarCalculator.time(of: .rise, on: day, coordinates: tromso, timeZone: tz) == nil)
    }

    @Test func elevationIsHighAtNoonAndNegativeAtMidnight() {
        let noon = SolarCalculator.elevation(at: date("2026-06-21T12:02:00Z"), coordinates: london)
        let midnight = SolarCalculator.elevation(at: date("2026-06-21T00:02:00Z"), coordinates: london)
        #expect(abs(noon - 61.9) < 0.5)
        #expect(midnight < -10)
    }
}
