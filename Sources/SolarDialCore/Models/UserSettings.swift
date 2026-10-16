import Foundation

public struct UserSettings: Codable, Equatable, Sendable {
    public var dayKelvin: Double = 6500
    public var sunsetKelvin: Double = 3400
    public var bedtimeKelvin: Double = 2300
    /// Minutes after local midnight.
    public var wakeMinutes: Int = 7 * 60
    /// Per-weekday wake times overriding `wakeMinutes`. Keys are `Calendar` weekdays (1 = Sunday … 7 = Saturday).
    public var wakeMinutesByWeekday: [Int: Int] = [:]
    /// Bedtime is this long before wake time.
    public var sleepMinutes: Int = 8 * 60 + 30
    /// Length of the sunrise, sunset and bedtime ramps.
    public var transitionMinutes: Int = 60
    public var disableForFullscreen: Bool = true
    public var disabledBundleIDs: Set<String> = []
    /// IANA time-zone identifier whose `zone.tab` city overrides automatic location when set.
    public var manualTimeZone: String?
    /// Switch macOS between light and dark appearance at sunrise and sunset.
    public var darkModeSync: Bool = false
    /// Post a notification shortly after bedtime.
    public var bedtimeReminder: Bool = false
    /// Display brightness reached at bedtime, ramping with the bedtime colour. 1 = no dimming.
    public var bedtimeBrightness: Double = 1
    public var movieKelvin: Double = 4100
    public var movieMinutes: Int = 150

    public static let dayKelvinRange: ClosedRange<Double> = 4500...6500
    public static let sunsetKelvinRange: ClosedRange<Double> = 1900...5000
    public static let bedtimeKelvinRange: ClosedRange<Double> = 1200...4000
    public static let movieKelvinRange: ClosedRange<Double> = 2700...6500
    public static let bedtimeBrightnessRange: ClosedRange<Double> = 0.4...1

    public init() {}

    /// Bedtime for the default wake time.
    public var bedtimeMinutes: Int {
        bedtimeMinutes(forWake: wakeMinutes)
    }

    /// Wake time on `weekday` (1 = Sunday … 7 = Saturday), falling back to `wakeMinutes`.
    public func wakeMinutes(onWeekday weekday: Int) -> Int {
        wakeMinutesByWeekday[weekday] ?? wakeMinutes
    }

    /// Bedtime the night before waking at `wake`, as minutes after local midnight.
    public func bedtimeMinutes(forWake wake: Int) -> Int {
        ((wake - sleepMinutes) % 1440 + 1440) % 1440
    }

    /// Missing keys fall back to defaults so settings survive new fields being added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserSettings()
        dayKelvin = try c.decodeIfPresent(Double.self, forKey: .dayKelvin) ?? d.dayKelvin
        sunsetKelvin = try c.decodeIfPresent(Double.self, forKey: .sunsetKelvin) ?? d.sunsetKelvin
        bedtimeKelvin = try c.decodeIfPresent(Double.self, forKey: .bedtimeKelvin) ?? d.bedtimeKelvin
        wakeMinutes = try c.decodeIfPresent(Int.self, forKey: .wakeMinutes) ?? d.wakeMinutes
        wakeMinutesByWeekday = try c.decodeIfPresent([Int: Int].self, forKey: .wakeMinutesByWeekday)
            ?? d.wakeMinutesByWeekday
        sleepMinutes = try c.decodeIfPresent(Int.self, forKey: .sleepMinutes) ?? d.sleepMinutes
        transitionMinutes = try c.decodeIfPresent(Int.self, forKey: .transitionMinutes) ?? d.transitionMinutes
        disableForFullscreen = try c.decodeIfPresent(Bool.self, forKey: .disableForFullscreen) ?? d.disableForFullscreen
        disabledBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .disabledBundleIDs) ?? d.disabledBundleIDs
        manualTimeZone = try c.decodeIfPresent(String.self, forKey: .manualTimeZone)
        darkModeSync = try c.decodeIfPresent(Bool.self, forKey: .darkModeSync) ?? d.darkModeSync
        bedtimeReminder = try c.decodeIfPresent(Bool.self, forKey: .bedtimeReminder) ?? d.bedtimeReminder
        bedtimeBrightness = try c.decodeIfPresent(Double.self, forKey: .bedtimeBrightness) ?? d.bedtimeBrightness
        movieKelvin = try c.decodeIfPresent(Double.self, forKey: .movieKelvin) ?? d.movieKelvin
        movieMinutes = try c.decodeIfPresent(Int.self, forKey: .movieMinutes) ?? d.movieMinutes
    }
}
