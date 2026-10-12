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
}

/// Works out the scheduled colour temperature for an instant.
///
/// Two independent weights are blended in mired space:
/// - daylight: ramps up at the later of sunrise and wake time, ramps down at sunset;
/// - bedtime: ramps up over the transition ending at bedtime, holds until wake, ramps down after wake.
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
        let daylight = daylightWeight(at: date, sunrise: sunrise, sunset: sunset)
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
        return ScheduleResult(kelvin: kelvin, phase: phase, sunrise: sunrise, sunset: sunset)
    }

    /// When daytime colour next starts returning after `date`: the later of sunrise and wake time.
    public func nextMorning(after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        for offset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let start = morningStart(on: day, sunrise: SolarCalculator.time(
                      of: .rise, on: day, coordinates: coordinates, timeZone: timeZone))
            else { continue }
            if start > date { return start }
        }
        return date.addingTimeInterval(12 * 3600)
    }

    func daylightWeight(at date: Date, sunrise: Date?, sunset: Date?) -> Double {
        guard let sunrise, let sunset else {
            let elevation = SolarCalculator.elevation(at: date, coordinates: coordinates)
            return elevation > SolarCalculator.horizonAltitude ? 1 : 0
        }
        let transition = Double(settings.transitionMinutes) * 60
        guard let start = morningStart(on: date, sunrise: sunrise) else { return 0 }
        let up = ramp(date.timeIntervalSince(start), over: transition)
        let down = ramp(date.timeIntervalSince(sunset), over: transition)
        return min(up, 1 - down)
    }

    func bedtimeWeight(at date: Date) -> Double {
        let now = minutesIntoDay(date)
        let transition = Double(settings.transitionMinutes)
        let bedtime = Double(settings.bedtimeMinutes)
        let wake = Double(settings.wakeMinutes)

        if circular(now - bedtime) < circular(wake - bedtime) { return 1 }
        let sinceWake = circular(now - wake)
        if sinceWake < transition { return 1 - sinceWake / transition }
        let untilBedtime = circular(bedtime - now)
        if untilBedtime < transition { return 1 - untilBedtime / transition }
        return 0
    }

    private func morningStart(on day: Date, sunrise: Date?) -> Date? {
        guard let sunrise else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let wake = calendar.date(
            bySettingHour: settings.wakeMinutes / 60, minute: settings.wakeMinutes % 60, second: 0, of: day)
        else { return sunrise }
        return max(sunrise, wake)
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
