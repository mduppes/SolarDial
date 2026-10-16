import Foundation

public enum Phase: String, Sendable {
    case day
    case sunset
    case bedtime
    case transition
}

public struct ScheduleResult: Equatable, Sendable {
    public var kelvin: Double
    public var phase: Phase
    public var sunrise: Date?
    public var sunset: Date?
    /// 0 at night, 1 in full daytime colour.
    public var daylight: Double
    /// 0 outside bedtime, 1 during it.
    public var bedtime: Double

    /// Brightness scale, dimming towards `UserSettings.bedtimeBrightness` with the bedtime ramp.
    public var brightness: Double

    /// Whether macOS should be in dark appearance (for dark-mode sync).
    public var prefersDarkAppearance: Bool { daylight < 0.5 }

    public var target: DisplayTarget { DisplayTarget(kelvin: kelvin, brightness: brightness) }
}

/// Works out the scheduled colour temperature for an instant.
///
/// Two independent weights are blended in mired space:
/// - daylight: ramps up over the transition, ending at the later of sunrise and wake time, and ramps down at sunset;
/// - bedtime: ramps up over the transition ending at bedtime, holds, then ramps down over the same morning window so it is gone when daytime colour is fully on.
///
/// Wake time can differ by weekday. Each night belongs to the morning it ends on: bedtime is that morning's wake time minus `sleepMinutes`.
public struct ScheduleEngine: Sendable {
    public var settings: UserSettings
    public var coordinates: Coordinates
    public var timeZone: TimeZone

    public init(settings: UserSettings, coordinates: Coordinates, timeZone: TimeZone) {
        self.settings = settings
        self.coordinates = coordinates
        self.timeZone = timeZone
    }

    public func evaluate(at date: Date) -> ScheduleResult {
        let sunrise = SolarCalculator.time(of: .rise, on: date, coordinates: coordinates, timeZone: timeZone)
        let sunset = SolarCalculator.time(of: .set, on: date, coordinates: coordinates, timeZone: timeZone)
        let anchor = morningAnchor(on: date, sunrise: sunrise)
        let daylight = daylightWeight(at: date, sunrise: sunrise, sunset: sunset, anchor: anchor)
        let bedtime = bedtimeWeight(at: date)

        let evening = ColorTemperature.blend(settings.sunsetKelvin, settings.dayKelvin, fraction: daylight)
        let kelvin = ColorTemperature.blend(evening, settings.bedtimeKelvin, fraction: bedtime)

        let phase: Phase
        if bedtime >= 1 {
            phase = .bedtime
        } else if bedtime > 0 || (daylight > 0 && daylight < 1) {
            phase = .transition
        } else {
            phase = daylight >= 1 ? .day : .sunset
        }
        let brightness = 1 - (1 - settings.bedtimeBrightness.clamped(to: 0...1)) * bedtime
        return ScheduleResult(
            kelvin: kelvin, phase: phase, sunrise: sunrise, sunset: sunset,
            daylight: daylight, bedtime: bedtime, brightness: brightness)
    }

    /// The schedule sampled across the local calendar day containing `day`, for graphing.
    public func dailyCurve(on day: Date, step: TimeInterval = 600) -> [(date: Date, result: ScheduleResult)] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start), step > 0 else { return [] }
        return stride(from: start.timeIntervalSince1970, through: end.timeIntervalSince1970, by: step).map {
            let date = Date(timeIntervalSince1970: $0)
            return (date, evaluate(at: date))
        }
    }

    /// Minutes from `date` until the next wake time.
    public func minutesUntilWake(at date: Date) -> Double {
        for offset in 0...7 {
            guard let wake = wakeTime(dayOffset: offset, from: date), wake > date else { continue }
            return wake.timeIntervalSince(date) / 60
        }
        return 0
    }

    /// Minutes since the most recent bedtime.
    public func minutesSinceBedtime(at date: Date) -> Double {
        let bedtimes = (-1...1).compactMap { bedtime(dayOffset: $0, from: date) }.filter { $0 <= date }
        guard let latest = bedtimes.max() else { return 0 }
        return date.timeIntervalSince(latest) / 60
    }

    /// When the next return to daytime colour begins: `transitionMinutes` before the later of sunrise and wake.
    public func nextMorning(after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let transition = Double(settings.transitionMinutes) * 60
        for offset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let sunrise = SolarCalculator.time(of: .rise, on: day, coordinates: coordinates, timeZone: timeZone)
            guard let anchor = morningAnchor(on: day, sunrise: sunrise) else { continue }
            let start = anchor.addingTimeInterval(-transition)
            if start > date { return start }
        }
        return date.addingTimeInterval(12 * 3600)
    }

    func daylightWeight(at date: Date, sunrise: Date?, sunset: Date?, anchor: Date?) -> Double {
        if sunrise == nil || sunset == nil {
            // Polar day or night: follow the sun's elevation.
            let elevation = SolarCalculator.elevation(at: date, coordinates: coordinates)
            return elevation > SolarCalculator.horizonAltitude ? 1 : 0
        }
        guard let sunset, let anchor else { return 0 }
        let transition = Double(settings.transitionMinutes) * 60
        // The ramp finishes at the anchor, so wake time (when it is the later of the two) is already daytime.
        let start = anchor.addingTimeInterval(-transition)
        let up = ramp(date.timeIntervalSince(start), over: transition)
        let down = ramp(date.timeIntervalSince(sunset), over: transition)
        return min(up, 1 - down)
    }

    /// Bedtime colour for the nights ending this morning and tomorrow morning.
    /// Each ramps up to its bedtime and back down to its morning anchor; the stronger one wins.
    func bedtimeWeight(at date: Date) -> Double {
        let transition = Double(settings.transitionMinutes) * 60
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var weight = 0.0
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let wake = wakeTime(on: day) else { continue }
            let sunrise = SolarCalculator.time(of: .rise, on: day, coordinates: coordinates, timeZone: timeZone)
            let morningEnd = morningAnchor(on: day, sunrise: sunrise) ?? wake
            let bedtime = wake.addingTimeInterval(-Double(settings.sleepMinutes) * 60)
            let up = ramp(date.timeIntervalSince(bedtime.addingTimeInterval(-transition)), over: transition)
            let down = ramp(date.timeIntervalSince(morningEnd.addingTimeInterval(-transition)), over: transition)
            weight = max(weight, min(up, 1 - down))
        }
        return weight
    }

    /// The instant daytime colour is fully on: the later of this local day's sunrise and wake time.
    ///
    /// Wake is built from the calendar day of `day`. `date(bySettingHour:of:)` searches forward by default,
    /// so once 07:00 has passed it can answer with tomorrow and leave the rest of the day on the night ramp.
    private func morningAnchor(on day: Date, sunrise: Date?) -> Date? {
        guard let wake = wakeTime(on: day) else { return sunrise }
        guard let sunrise else { return wake }
        return max(sunrise, wake)
    }

    /// Wake time on the local calendar day containing `day`, using that weekday's setting.
    private func wakeTime(on day: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: day)
        return clockTime(minutes: settings.wakeMinutes(onWeekday: weekday), on: day)
    }

    private func wakeTime(dayOffset: Int, from date: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(byAdding: .day, value: dayOffset, to: date).flatMap(wakeTime(on:))
    }

    /// Bedtime for the night ending on the morning `dayOffset` days from `date`.
    private func bedtime(dayOffset: Int, from date: Date) -> Date? {
        wakeTime(dayOffset: dayOffset, from: date)?.addingTimeInterval(-Double(settings.sleepMinutes) * 60)
    }

    /// `minutes` after local midnight on the calendar day that contains `day`, including when that time is already past.
    private func clockTime(minutes: Int, on day: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        var parts = DateComponents()
        parts.timeZone = timeZone
        parts.year = dayParts.year
        parts.month = dayParts.month
        parts.day = dayParts.day
        parts.hour = minutes / 60
        parts.minute = minutes % 60
        parts.second = 0
        return calendar.date(from: parts)
    }

    private func ramp(_ elapsed: TimeInterval, over duration: TimeInterval) -> Double {
        guard duration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return (elapsed / duration).clamped(to: 0...1)
    }
}
