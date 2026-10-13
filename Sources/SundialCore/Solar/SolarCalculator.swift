import Foundation

/// NOAA solar position equations (the "General Solar Position Calculations" spreadsheet).
/// Accurate to about a minute for sunrise/sunset between ±72° latitude.
public enum SolarCalculator {
    public enum Event: Sendable {
        case rise
        case set
    }

    /// Standard sunrise/sunset altitude: the sun's upper limb on the horizon, with refraction.
    public static let horizonAltitude = -0.833
    public static let civilTwilightAltitude = -6.0

    /// Solar elevation in degrees above the horizon (no refraction correction).
    public static func elevation(at date: Date, coordinates: Coordinates) -> Double {
        let sun = SunParameters(julianDay: julianDay(date))
        let utcMinutes = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400) / 60
        var trueSolarTime = (utcMinutes + sun.equationOfTime + 4 * coordinates.longitude)
            .truncatingRemainder(dividingBy: 1440)
        if trueSolarTime < 0 { trueSolarTime += 1440 }
        let hourAngle = radians(trueSolarTime / 4 - 180)
        let lat = radians(coordinates.latitude)
        let cosZenith = sin(lat) * sin(sun.declination) + cos(lat) * cos(sun.declination) * cos(hourAngle)
        return 90 - degrees(acos(min(1, max(-1, cosZenith))))
    }

    /// The instant the sun crosses `altitude` on the local calendar day containing `day`.
    /// Returns nil when it never does (polar day or night).
    public static func time(
        of event: Event,
        on day: Date,
        coordinates: Coordinates,
        timeZone: TimeZone,
        altitude: Double = horizonAltitude
    ) -> Date? {
        guard let reference = utcReferenceMidnight(for: day, longitude: coordinates.longitude, timeZone: timeZone)
        else { return nil }
        let sign: Double = event == .rise ? -1 : 1
        var estimate = reference.addingTimeInterval(12 * 3600)
        for _ in 0..<2 {
            let sun = SunParameters(julianDay: julianDay(estimate))
            guard let hourAngle = hourAngle(
                latitude: coordinates.latitude, declination: sun.declination, altitude: altitude)
            else { return nil }
            let noonMinutes = 720 - 4 * coordinates.longitude - sun.equationOfTime
            let minutes = noonMinutes + sign * 4 * hourAngle
            estimate = reference.addingTimeInterval(minutes * 60)
        }
        return estimate
    }

    /// Hour angle in degrees at which the sun reaches `altitude`, or nil if it never does.
    static func hourAngle(latitude: Double, declination: Double, altitude: Double) -> Double? {
        let lat = radians(latitude)
        let cosH = (sin(radians(altitude)) - sin(lat) * sin(declination)) / (cos(lat) * cos(declination))
        guard (-1...1).contains(cosH) else { return nil }
        return degrees(acos(cosH))
    }

    /// The UTC midnight from which solar noon for the local day is offset by `720 - 4·lon` minutes.
    static func utcReferenceMidnight(for day: Date, longitude: Double, timeZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let localNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) else { return nil }
        let solarUTC = localNoon.timeIntervalSince1970 + 4 * longitude * 60
        let midnight = (solarUTC / 86_400).rounded(.down) * 86_400
        return Date(timeIntervalSince1970: midnight)
    }

    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    struct SunParameters {
        /// Radians.
        let declination: Double
        /// Minutes.
        let equationOfTime: Double

        init(julianDay: Double) {
            let t = (julianDay - 2_451_545) / 36_525
            let meanLongitude = (280.46646 + t * (36_000.76983 + t * 0.0003032))
                .truncatingRemainder(dividingBy: 360)
            let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
            let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
            let m = radians(meanAnomaly)
            let center = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
                + sin(2 * m) * (0.019993 - 0.000101 * t)
                + sin(3 * m) * 0.000289
            let trueLongitude = meanLongitude + center
            let omega = radians(125.04 - 1934.136 * t)
            let apparentLongitude = radians(trueLongitude - 0.00569 - 0.00478 * sin(omega))
            let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
            let obliquity = radians(meanObliquity + 0.00256 * cos(omega))
            declination = asin(sin(obliquity) * sin(apparentLongitude))

            let y = pow(tan(obliquity / 2), 2)
            let l0 = radians(meanLongitude)
            let e = eccentricity
            equationOfTime = 4 * degrees(
                y * sin(2 * l0)
                    - 2 * e * sin(m)
                    + 4 * e * y * sin(m) * cos(2 * l0)
                    - 0.5 * y * y * sin(4 * l0)
                    - 1.25 * e * e * sin(2 * m))
        }
    }
}

@inline(__always) func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
@inline(__always) func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
