import Foundation
import Testing
@testable import FluxCore

struct DisplayTargetTests {
    let base = GammaTable(red: [0, 0.5, 1], green: [0, 0.5, 1], blue: [0, 0.5, 1])

    @Test func darkroomIsInvertedRedOnly() {
        let table = DisplayTarget.darkroom.table(base: base)
        #expect(table.red == [1, 0.5, 0])
        #expect(table.green == [0, 0, 0])
        #expect(table.blue == [0, 0, 0])
    }

    @Test func kelvinFadeGoesThroughMiredSpace() {
        let start = Date(timeIntervalSince1970: 0)
        let fade = TargetFade(from: .kelvin(6000), to: .kelvin(3000), start: start, duration: 2)
        #expect(fade.current(at: start.addingTimeInterval(1)) == .kelvin(4000))
        #expect(fade.table(at: start.addingTimeInterval(2), base: base) == base.tinted(kelvin: 3000))
    }

    @Test func darkroomFadeCrossfadesTables() {
        let start = Date(timeIntervalSince1970: 0)
        let fade = TargetFade(from: .neutral, to: .darkroom, start: start, duration: 2)
        let mid = fade.table(at: start.addingTimeInterval(1), base: base)
        #expect(mid.red == [0.5, 0.5, 0.5])
        #expect(mid.blue == [0, 0.25, 0.5])
        #expect(fade.current(at: start.addingTimeInterval(0.5)) == .neutral)
        #expect(fade.current(at: start.addingTimeInterval(1.5)) == .darkroom)
    }

    @Test func needsChange() {
        #expect(!DisplayTarget.kelvin(3400).needsChange(to: .kelvin(3400.5)))
        #expect(DisplayTarget.kelvin(3400).needsChange(to: .darkroom))
    }
}

struct TargetResolverTests {
    let later = Date(timeIntervalSince1970: 10_000)

    func target(_ inputs: TargetResolver.Inputs) -> DisplayTarget { TargetResolver.target(for: inputs) }

    @Test func scheduleByDefault() {
        #expect(target(.init(scheduledKelvin: 3400)) == .kelvin(3400))
    }

    @Test func fullscreenAndAppDisableUntint() {
        #expect(target(.init(scheduledKelvin: 3400, fullscreen: true)) == .neutral)
        #expect(target(.init(scheduledKelvin: 3400, appDisabled: true)) == .neutral)
    }

    @Test func darkroomBeatsFullscreenButNotTemporaryDisable() {
        let mode = TintMode.darkroom(until: later)
        #expect(target(.init(scheduledKelvin: 3400, mode: mode, fullscreen: true)) == .darkroom)
        #expect(target(.init(scheduledKelvin: 3400, mode: mode, temporarilyDisabled: true)) == .neutral)
    }

    @Test func movieModeCapsWarmthOnly() {
        let mode = TintMode.movie(until: later)
        #expect(target(.init(scheduledKelvin: 2300, mode: mode)) == .kelvin(TintMode.movieKelvin))
        #expect(target(.init(scheduledKelvin: 6500, mode: mode)) == .kelvin(6500))
    }

    @Test func previewWins() {
        #expect(target(.init(scheduledKelvin: 6500, temporarilyDisabled: true, previewKelvin: 2700)) == .kelvin(2700))
    }

    @Test func movieModeLastsTwoAndAHalfHours() {
        let now = Date(timeIntervalSince1970: 0)
        let mode = TintMode.movie(from: now)
        #expect(mode.isActive(at: now.addingTimeInterval(2.5 * 3600 - 1)))
        #expect(!mode.isActive(at: now.addingTimeInterval(2.5 * 3600)))
    }
}

struct BedtimeReminderTests {
    let tz = TimeZone(identifier: "America/Sao_Paulo")!
    var engine: ScheduleEngine {
        ScheduleEngine(
            settings: UserSettings(), coordinates: Coordinates(latitude: -23.55, longitude: -46.63), timeZone: tz)
    }

    func local(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: hour, minute: minute))!
    }

    @Test func remindsOnlyJustAfterBedtime() {
        #expect(!BedtimeReminder.shouldRemind(at: local(22, 20), schedule: engine, lastReminder: nil))
        #expect(BedtimeReminder.shouldRemind(at: local(22, 35), schedule: engine, lastReminder: nil))
        #expect(!BedtimeReminder.shouldRemind(at: local(23, 0), schedule: engine, lastReminder: nil))
        #expect(!BedtimeReminder.shouldRemind(at: local(3, 0), schedule: engine, lastReminder: nil))
    }

    @Test func remindsOncePerNight() {
        let first = local(22, 30)
        #expect(!BedtimeReminder.shouldRemind(at: local(22, 40), schedule: engine, lastReminder: first))
    }

    @Test func messageRoundsToHalfHours() {
        #expect(BedtimeReminder.message(at: local(22, 30), schedule: engine) == "You're waking up in 8½ hours.")
        #expect(BedtimeReminder.message(at: local(23, 0), schedule: engine) == "You're waking up in 8 hours.")
    }
}
