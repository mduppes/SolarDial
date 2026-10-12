import Foundation

/// Movie mode: a fixed, user-chosen colour temperature at full brightness that ends by itself.
public struct MovieMode: Equatable, Sendable {
    public var until: Date

    public init(until: Date) {
        self.until = until
    }

    public static func starting(at date: Date, minutes: Int) -> MovieMode {
        MovieMode(until: date.addingTimeInterval(Double(minutes) * 60))
    }

    public func isActive(at date: Date) -> Bool {
        date < until
    }
}

/// The rules for combining the schedule with movie mode, the disables and previews, for one display.
public enum TargetResolver {
    public struct Inputs: Equatable, Sendable {
        public var scheduled: DisplayTarget
        /// Movie mode's colour temperature, when it's on.
        public var movieKelvin: Double?
        /// "Disable for an hour" / "until sunrise".
        public var temporarilyDisabled: Bool
        /// The frontmost app is on the per-app disable list.
        public var appDisabled: Bool
        /// This display is showing a full-screen window (and full-screen disable is on).
        public var fullscreen: Bool
        /// A target being previewed from the settings window.
        public var preview: DisplayTarget?

        public init(
            scheduled: DisplayTarget, movieKelvin: Double? = nil, temporarilyDisabled: Bool = false,
            appDisabled: Bool = false, fullscreen: Bool = false, preview: DisplayTarget? = nil
        ) {
            self.scheduled = scheduled
            self.movieKelvin = movieKelvin
            self.temporarilyDisabled = temporarilyDisabled
            self.appDisabled = appDisabled
            self.fullscreen = fullscreen
            self.preview = preview
        }
    }

    /// Order of precedence: preview, any disable (neutral), movie mode, schedule.
    public static func target(for inputs: Inputs) -> DisplayTarget {
        if let preview = inputs.preview { return preview }
        if inputs.temporarilyDisabled || inputs.appDisabled || inputs.fullscreen { return .neutral }
        if let movie = inputs.movieKelvin { return DisplayTarget(kelvin: movie) }
        return inputs.scheduled
    }
}
