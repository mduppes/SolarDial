import Foundation
import Testing
@testable import SolarDialCore

struct DisplayTargetTests {
    let base = GammaTable(red: [0, 0.5, 1], green: [0, 0.5, 1], blue: [0, 0.5, 1])

    @Test func brightnessScalesAllChannels() {
        let table = DisplayTarget(kelvin: 6500, brightness: 0.5).table(base: base)
        #expect(table.red == [0, 0.25, 0.5])
        #expect(table.blue == [0, 0.25, 0.5])
    }

    @Test func fadeBlendsKelvinInMiredsAndBrightnessLinearly() {
        let start = Date(timeIntervalSince1970: 0)
        let fade = TargetFade(
            from: DisplayTarget(kelvin: 6000, brightness: 1), to: DisplayTarget(kelvin: 3000, brightness: 0.5),
            start: start, duration: 2)
        let mid = fade.current(at: start.addingTimeInterval(1))
        #expect(abs(mid.kelvin - 4000) < 1e-9)
        #expect(abs(mid.brightness - 0.75) < 1e-9)
        #expect(fade.current(at: start.addingTimeInterval(2)) == fade.to)
        #expect(fade.isFinished(at: start.addingTimeInterval(2)))
    }

    @Test func needsChange() {
        #expect(!DisplayTarget(kelvin: 3400).needsChange(to: DisplayTarget(kelvin: 3400.5)))
        #expect(DisplayTarget(kelvin: 3400).needsChange(to: DisplayTarget(kelvin: 3400, brightness: 0.9)))
    }
}

struct TargetResolverTests {
    let scheduled = DisplayTarget(kelvin: 2300, brightness: 0.7)

    func target(_ inputs: TargetResolver.Inputs) -> DisplayTarget { TargetResolver.target(for: inputs) }

    @Test func scheduleByDefault() {
        #expect(target(.init(scheduled: scheduled)) == scheduled)
    }

    @Test func disablesUntintAtFullBrightness() {
        #expect(target(.init(scheduled: scheduled, fullscreen: true)) == .neutral)
        #expect(target(.init(scheduled: scheduled, appDisabled: true)) == .neutral)
        #expect(target(.init(scheduled: scheduled, temporarilyDisabled: true)) == .neutral)
    }

    @Test func movieModeUsesTheChosenKelvinAtFullBrightness() {
        #expect(target(.init(scheduled: scheduled, movieKelvin: 4100)) == DisplayTarget(kelvin: 4100))
        #expect(target(.init(scheduled: scheduled, movieKelvin: 4100, fullscreen: true)) == .neutral)
    }

    @Test func previewWins() {
        let preview = DisplayTarget(kelvin: 2700)
        #expect(target(.init(scheduled: scheduled, temporarilyDisabled: true, preview: preview)) == preview)
    }

    @Test func movieModeDuration() {
        let now = Date(timeIntervalSince1970: 0)
        let mode = MovieMode.starting(at: now, minutes: 150)
        #expect(mode.isActive(at: now.addingTimeInterval(150 * 60 - 1)))
        #expect(!mode.isActive(at: now.addingTimeInterval(150 * 60)))
    }
}

struct SettingsHistoryTests {
    @Test func dragCollapsesIntoOneStep() {
        var history = SettingsHistory()
        var original = UserSettings()
        original.sunsetKelvin = 3400
        let t0 = Date(timeIntervalSince1970: 0)
        history.record(original, at: t0)
        var mid = original
        mid.sunsetKelvin = 3300
        history.record(mid, at: t0.addingTimeInterval(0.3))
        #expect(history.undo() == original)
        #expect(!history.canUndo)
    }

    @Test func separateChangesUndoInOrder() {
        var history = SettingsHistory()
        var a = UserSettings()
        a.dayKelvin = 6000
        var b = a
        b.dayKelvin = 5500
        let t0 = Date(timeIntervalSince1970: 0)
        history.record(a, at: t0)
        history.record(b, at: t0.addingTimeInterval(5))
        #expect(history.undo() == b)
        #expect(history.undo() == a)
        #expect(history.undo() == nil)
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
