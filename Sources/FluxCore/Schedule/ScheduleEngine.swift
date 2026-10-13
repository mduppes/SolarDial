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
        let bedtime = bedtimeWeight(at: date, morningEnd: anchor)

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
        circular(Double(settings.wakeMinutes) - minutesIntoDay(date))
    }

    /// Minutes since the most recent bedtime.
    public func minutesSinceBedtime(at date: Date) -> Double {
        circular(minutesIntoDay(date) - Double(settings.bedtimeMinutes))
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

    /// `morningEnd` is when bedtime colour has fully given way to the day. Nil falls back to the wake clock time.
    func bedtimeWeight(at date: Date, morningEnd: Date?) -> Double {
        let now = minutesIntoDay(date)
        let transition = Double(settings.transitionMinutes)
        let bedtime = Double(settings.bedtimeMinutes)
        let wake = morningEnd.map(minutesIntoDay) ?? Double(settings.wakeMinutes)
        let night = circular(wake - bedtime)
        let sinceBedtime = circular(now - bedtime)
        let untilWake = circular(wake - now)

        if transition <= 0 {
            return sinceBedtime < night ? 1 : 0
        }
        // From bedtime until the morning ramp starts.
        if sinceBedtime + untilWake <= night + 1e-4 {
            if night > transition, sinceBedtime < night - transition { return 1 }
            return (untilWake / transition).clamped(to: 0...1)
        }
        let untilBedtime = circular(bedtime - now)
        if untilBedtime <= transition { return 1 - untilBedtime / transition }
        return 0
    }

    /// The instant daytime colour is fully on: the later of this local day's sunrise and wake time.
    ///
    /// Wake is built from the calendar day of `day`. `date(bySettingHour:of:)` searches forward by default,
    /// so once 07:00 has passed it can answer with tomorrow and leave the rest of the day on the night ramp.
    private func morningAnchor(on day: Date, sunrise: Date?) -> Date? {
        guard let wake = clockTime(minutes: settings.wakeMinutes, on: day) else { return sunrise }
        guard let sunrise else { return wake }
        return max(sunrise, wake)
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

    private func minutesIntoDay(_ date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0) * 60 + Double(parts.minute ?? 0) + Double(parts.second ?? 0) / 60
    }

    private func circular(_ minutes: Double) -> Double {
        let m = minutes.truncatingRemainder(dividingBy: 1440)
        return m < 0 ? m + 1440 : m
    }

    private func ramp(_ elapsed: TimeInterval, over duration: TimeInterval) -> Double {
        guard duration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return (elapsed / duration).clamped(to: 0...1)
    }
}
