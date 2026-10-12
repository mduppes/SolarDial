import Foundation

/// A user-chosen mode that overrides the normal schedule and ends by itself.
public enum TintMode: Equatable, Sendable {
    /// Keeps colours closer to neutral so films keep their shadow detail and sky colours.
    case movie(until: Date)
    /// Red-only, inverted display.
    case darkroom(until: Date)

    public static let movieDuration: TimeInterval = 2.5 * 3600
    /// Movie mode never warms beyond this, but doesn't cool the screen either.
    public static let movieKelvin: Double = 4100

    public var endDate: Date {
        switch self {
        case .movie(let until), .darkroom(let until): until
        }
    }

    public func isActive(at date: Date) -> Bool {
        date < endDate
    }

    public static func movie(from date: Date) -> TintMode {
        .movie(until: date.addingTimeInterval(movieDuration))
    }

    public static func darkroomUntilSunrise(from date: Date, schedule: ScheduleEngine) -> TintMode {
        .darkroom(until: schedule.nextMorning(after: date))
    }
}

/// The rules for combining the schedule with modes and the various disables, for one display.
public enum TargetResolver {
    public struct Inputs: Equatable, Sendable {
        public var scheduledKelvin: Double
        public var mode: TintMode?
        /// "Disable for an hour" / "until sunrise".
        public var temporarilyDisabled: Bool
        /// The frontmost app is on the per-app disable list.
        public var appDisabled: Bool
        /// This display is showing a full-screen window (and full-screen disable is on).
        public var fullscreen: Bool
        /// A colour being previewed from the settings window.
        public var previewKelvin: Double?

        public init(
            scheduledKelvin: Double, mode: TintMode? = nil, temporarilyDisabled: Bool = false,
            appDisabled: Bool = false, fullscreen: Bool = false, previewKelvin: Double? = nil
        ) {
            self.scheduledKelvin = scheduledKelvin
            self.mode = mode
            self.temporarilyDisabled = temporarilyDisabled
            self.appDisabled = appDisabled
            self.fullscreen = fullscreen
            self.previewKelvin = previewKelvin
        }
    }

    /// Order of precedence: preview, temporary disable, darkroom, per-app / full-screen disable,
    /// movie mode, schedule. Darkroom deliberately beats the app and full-screen disables: a bright
    /// full-screen window is exactly what darkroom is meant to prevent.
    public static func target(for inputs: Inputs) -> DisplayTarget {
        if let preview = inputs.previewKelvin { return .kelvin(preview) }
        if inputs.temporarilyDisabled { return .neutral }
        if case .darkroom = inputs.mode { return .darkroom }
        if inputs.appDisabled || inputs.fullscreen { return .neutral }
        if case .movie = inputs.mode { return .kelvin(max(inputs.scheduledKelvin, TintMode.movieKelvin)) }
        return .kelvin(inputs.scheduledKelvin)
    }
}
