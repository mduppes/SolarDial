import Foundation
import Testing
@testable import FluxCore

struct ScheduleEngineTests {
    let tz = TimeZone(identifier: "America/Sao_Paulo")!
    let saoPaulo = Coordinates(latitude: -23.55, longitude: -46.63)

    var engine: ScheduleEngine {
        ScheduleEngine(settings: UserSettings(), coordinates: saoPaulo, timeZone: tz)
    }

    func local(_ hour: Int, _ minute: Int = 0, day: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    // Sunrise ≈ 05:36 and sunset ≈ 18:10 local on 2026-10-12; defaults: wake 07:00, bedtime 22:30.

    @Test func middayIsDayColour() {
        let result = engine.evaluate(at: local(13))
        #expect(result.phase == .day)
        #expect(result.kelvin == 6500)
    }

    @Test func eveningIsSunsetColour() {
        let result = engine.evaluate(at: local(20, 30))
        #expect(result.phase == .sunset)
        #expect(abs(result.kelvin - 3400) < 1e-6)
    }

    @Test func lateNightIsBedtimeColour() {
        for date in [local(23, 30), local(3), local(6, 59)] {
            let result = engine.evaluate(at: date)
            #expect(result.phase == .bedtime)
            #expect(abs(result.kelvin - 2300) < 1e-6)
        }
    }

    @Test func sunsetRampIsGradual() {
        let sunset = engine.evaluate(at: local(12)).sunset!
        let during = engine.evaluate(at: sunset.addingTimeInterval(30 * 60))
        #expect(during.phase == .transition)
        #expect(during.kelvin < 6500 && during.kelvin > 3400)
    }

    @Test func morningWaitsForWakeTimeEvenAfterSunrise() {
        let beforeWake = engine.evaluate(at: local(6, 30))
        let afterWake = engine.evaluate(at: local(8, 30))
        #expect(beforeWake.kelvin < 3000)
        #expect(afterWake.kelvin == 6500)
    }

    @Test func bedtimeAfterMidnightWraps() {
        var settings = UserSettings()
        settings.wakeMinutes = 9 * 60
        settings.sleepMinutes = 8 * 60 + 30
        let late = ScheduleEngine(settings: settings, coordinates: saoPaulo, timeZone: tz)
        #expect(settings.bedtimeMinutes == 30)
        #expect(late.evaluate(at: local(23, 0)).phase == .sunset)
        #expect(late.evaluate(at: local(23, 45)).phase == .transition)
        #expect(late.evaluate(at: local(1, 0)).phase == .bedtime)
    }

    @Test func nextMorningIsLaterOfSunriseAndWake() {
        let next = engine.nextMorning(after: local(21))
        #expect(next == local(7, day: 13))
        var settings = UserSettings()
        settings.wakeMinutes = 4 * 60
        let early = ScheduleEngine(settings: settings, coordinates: saoPaulo, timeZone: tz)
        let sunrise = early.nextMorning(after: local(21))
        #expect(sunrise > local(5, day: 13) && sunrise < local(6, day: 13))
    }

    @Test func temporaryDisableExpires() {
        let now = local(21)
        let disable = TemporaryDisable.oneHour(from: now)
        #expect(disable.isActive(at: now.addingTimeInterval(3599)))
        #expect(!disable.isActive(at: now.addingTimeInterval(3600)))
        let untilSunrise = TemporaryDisable.untilSunrise(from: now, schedule: engine)
        #expect(untilSunrise.endDate == local(7, day: 13))
    }
}
