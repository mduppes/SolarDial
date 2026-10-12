import Foundation

/// A Core Location fix, remembered together with the time zone that was active when it was taken.
public struct LocationFix: Codable, Equatable, Sendable {
    public var coordinates: Coordinates
    public var timeZoneIdentifier: String

    public init(coordinates: Coordinates, timeZoneIdentifier: String) {
        self.coordinates = coordinates
        self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public enum LocationSource: Equatable, Sendable {
    case manual
    case coreLocation
    case timeZone(String)
    case unknown
}

public struct ResolvedLocation: Equatable, Sendable {
    public var coordinates: Coordinates
    public var source: LocationSource
}

public enum LocationResolver {
    /// Picks the best coordinates available, in order: manual, a fix taken in the current
    /// time zone, the time zone's `zone.tab` entry, then a longitude estimated from the UTC offset.
    /// A fix taken in another time zone is ignored, so travelling never leaves a stale location in use.
    public static func resolve(
        manual: Coordinates?,
        lastFix: LocationFix?,
        timeZone: TimeZone,
        zoneTab: ZoneTab?,
        at date: Date = Date()
    ) -> ResolvedLocation {
        if let manual, manual.isValid {
            return ResolvedLocation(coordinates: manual, source: .manual)
        }
        if let lastFix, lastFix.timeZoneIdentifier == timeZone.identifier, lastFix.coordinates.isValid {
            return ResolvedLocation(coordinates: lastFix.coordinates, source: .coreLocation)
        }
        if let coordinates = zoneTab?.coordinates(for: timeZone.identifier) {
            return ResolvedLocation(coordinates: coordinates, source: .timeZone(timeZone.identifier))
        }
        let longitude = (Double(timeZone.secondsFromGMT(for: date)) / 3600 * 15).clamped(to: -180...180)
        return ResolvedLocation(coordinates: Coordinates(latitude: 0, longitude: longitude), source: .unknown)
    }
}
