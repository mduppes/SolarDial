import Foundation

public struct UserSettings: Codable, Equatable, Sendable {
    public var dayKelvin: Double = 6500
    public var sunsetKelvin: Double = 3400
    public var bedtimeKelvin: Double = 2300
    /// Minutes after local midnight.
    public var wakeMinutes: Int = 7 * 60
    /// Bedtime is this long before wake time.
    public var sleepMinutes: Int = 8 * 60 + 30
    /// Length of the sunrise, sunset and bedtime ramps.
    public var transitionMinutes: Int = 60
    public var disableForFullscreen: Bool = true
    public var disabledBundleIDs: Set<String> = []
    /// Overrides automatic location when set.
    public var manualCoordinates: Coordinates?
    /// Switch macOS between light and dark appearance at sunrise and sunset.
    public var darkModeSync: Bool = false
    /// Post a notification shortly after bedtime.
    public var bedtimeReminder: Bool = false

    public static let dayKelvinRange: ClosedRange<Double> = 4500...6500
    public static let sunsetKelvinRange: ClosedRange<Double> = 1900...5000
    public static let bedtimeKelvinRange: ClosedRange<Double> = 1200...4000

    public init() {}

    public var bedtimeMinutes: Int {
        ((wakeMinutes - sleepMinutes) % 1440 + 1440) % 1440
    }

    /// Missing keys fall back to defaults so settings survive new fields being added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserSettings()
        dayKelvin = try c.decodeIfPresent(Double.self, forKey: .dayKelvin) ?? d.dayKelvin
        sunsetKelvin = try c.decodeIfPresent(Double.self, forKey: .sunsetKelvin) ?? d.sunsetKelvin
        bedtimeKelvin = try c.decodeIfPresent(Double.self, forKey: .bedtimeKelvin) ?? d.bedtimeKelvin
        wakeMinutes = try c.decodeIfPresent(Int.self, forKey: .wakeMinutes) ?? d.wakeMinutes
        sleepMinutes = try c.decodeIfPresent(Int.self, forKey: .sleepMinutes) ?? d.sleepMinutes
        transitionMinutes = try c.decodeIfPresent(Int.self, forKey: .transitionMinutes) ?? d.transitionMinutes
        disableForFullscreen = try c.decodeIfPresent(Bool.self, forKey: .disableForFullscreen) ?? d.disableForFullscreen
        disabledBundleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .disabledBundleIDs) ?? d.disabledBundleIDs
        manualCoordinates = try c.decodeIfPresent(Coordinates.self, forKey: .manualCoordinates)
        darkModeSync = try c.decodeIfPresent(Bool.self, forKey: .darkModeSync) ?? d.darkModeSync
        bedtimeReminder = try c.decodeIfPresent(Bool.self, forKey: .bedtimeReminder) ?? d.bedtimeReminder
    }
}
