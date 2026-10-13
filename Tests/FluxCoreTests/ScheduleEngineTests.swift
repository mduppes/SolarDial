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
        // 05:30 is still before the 06:00–07:00 morning ramp (wake 07:00, 60 min transition).
        for date in [local(23, 30), local(3), local(5, 30)] {
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

    @Test func morningColourIsCompleteAtWakeEvenAfterSunrise() {
        // Sunrise is ~05:36, so the 60 min ramp runs 06:00–07:00 and finishes at wake.
        let beforeRamp = engine.evaluate(at: local(5, 30))
        let during = engine.evaluate(at: local(6, 30))
        let atWake = engine.evaluate(at: local(7))
        let afterWake = engine.evaluate(at: local(8, 30))
        #expect(beforeRamp.phase == .bedtime)
        #expect(abs(beforeRamp.kelvin - 2300) < 1e-6)
        #expect(during.phase == .transition)
        #expect(abs(during.daylight - 0.5) < 0.02)
        #expect(abs(during.bedtime - 0.5) < 0.02)
        #expect(atWake.phase == .day)
        #expect(atWake.kelvin == 6500)
        #expect(afterWake.kelvin == 6500)
    }

    @Test func sunriseKeepsTheTintUntilTheSunIsUp() {
        var settings = UserSettings()
        settings.wakeMinutes = 4 * 60
        let early = ScheduleEngine(settings: settings, coordinates: saoPaulo, timeZone: tz)
        #expect(early.evaluate(at: local(4)).phase == .bedtime)
        #expect(early.evaluate(at: local(6, 30)).kelvin == 6500)
    }

    /// 2026-10-13 07:11 America/Sao_Paulo (10:11Z), Florianópolis. Wake 07:00, slow transition.
    /// The screen was still ~2470 K because the ramp ran for an hour after wake.
    @Test func floripaMorningIsDayColourElevenMinutesAfterWake() throws {
        let settings = try JSONDecoder().decode(
            UserSettings.self,
            from: Data(
                """
                {"movieMinutes":150,"sunsetKelvin":3400,"movieKelvin":4100,"darkModeSync":false,\
                "bedtimeReminder":false,"transitionMinutes":60,"wakeMinutes":420,"bedtimeBrightness":1,\
                "bedtimeKelvin":2300,"disabledBundleIDs":[],"sleepMinutes":510,"dayKelvin":6500,\
                "disableForFullscreen":true}
                """.utf8))
        let floripa = Coordinates(latitude: -27.601319760054153, longitude: -48.61451200892745)
        let schedule = ScheduleEngine(settings: settings, coordinates: floripa, timeZone: tz)
        #expect(settings.bedtimeMinutes == 22 * 60 + 30)
        #expect(settings.wakeMinutes == 7 * 60)

        let atWakePlusEleven = local(7, 11, day: 13)
        let tenElevenZ = try Date("2026-10-13T10:11:00Z", strategy: .iso8601)
        #expect(atWakePlusEleven == tenElevenZ)

        let morning = schedule.evaluate(at: atWakePlusEleven)
        let sunrise = try #require(morning.sunrise)
        #expect(sunrise < local(7, day: 13))
        #expect(morning.phase == .day)
        #expect(morning.daylight == 1)
        #expect(morning.bedtime == 0)
        #expect(morning.kelvin == 6500)

        // Same engine, still running from the previous evening: night colour survives midnight,
        // and the afternoon after wake is daytime on that calendar day (wake does not slide to tomorrow).
        let previousEvening = schedule.evaluate(at: local(19, 42, day: 12))
        #expect(previousEvening.phase == .sunset)
        #expect(abs(previousEvening.kelvin - 3400) < 1e-6)
        let afterMidnight = schedule.evaluate(at: local(0, 30, day: 13))
        #expect(afterMidnight.phase == .bedtime)
        #expect(schedule.evaluate(at: local(13, day: 13)).kelvin == 6500)

        let scheduled = morning.target
        let resolved = TargetResolver.target(for: .init(scheduled: scheduled))
        #expect(resolved == scheduled)
        #expect(resolved.kelvin == 6500)
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

    @Test func nextMorningIsWhenTheRampBegins() {
        // Wake 07:00 and a 60 min transition: the ramp starts at 06:00, after sunrise.
        let next = engine.nextMorning(after: local(21))
        #expect(next == local(6, day: 13))
        var settings = UserSettings()
        settings.wakeMinutes = 4 * 60
        let early = ScheduleEngine(settings: settings, coordinates: saoPaulo, timeZone: tz)
        let starts = early.nextMorning(after: local(21))
        // Sunrise is ~05:36, so the ramp begins an hour before that, not at 04:00.
        #expect(starts > local(4, day: 13) && starts < local(5, day: 13))
    }

    @Test func bedtimeDimsWithTheRamp() {
        var settings = UserSettings()
        settings.bedtimeBrightness = 0.6
        let dimming = ScheduleEngine(settings: settings, coordinates: saoPaulo, timeZone: tz)
        #expect(dimming.evaluate(at: local(13)).brightness == 1)
        #expect(abs(dimming.evaluate(at: local(23, 30)).brightness - 0.6) < 1e-9)
        let ramp = dimming.evaluate(at: local(22)).brightness
        #expect(ramp < 1 && ramp > 0.6)
    }

    @Test func dailyCurveCoversTheLocalDay() {
        let curve = engine.dailyCurve(on: local(13), step: 3600)
        #expect(curve.count == 25)
        #expect(curve.first?.date == local(0))
        #expect(curve.contains { $0.result.phase == .day })
        #expect(curve.contains { $0.result.phase == .bedtime })
    }

    @Test func temporaryDisableExpires() {
        let now = local(21)
        let disable = TemporaryDisable.oneHour(from: now)
        #expect(disable.isActive(at: now.addingTimeInterval(3599)))
        #expect(!disable.isActive(at: now.addingTimeInterval(3600)))
        let untilSunrise = TemporaryDisable.untilSunrise(from: now, schedule: engine)
        #expect(untilSunrise.endDate == local(6, day: 13))
    }
}
