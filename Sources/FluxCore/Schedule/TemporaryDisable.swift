import Foundation

/// A user-requested pause in tinting that ends by itself.
public enum TemporaryDisable: Equatable, Sendable {
    case forOneHour(until: Date)
    case untilSunrise(until: Date)

    public var endDate: Date {
        switch self {
        case .forOneHour(let until), .untilSunrise(let until): until
        }
    }

    public func isActive(at date: Date) -> Bool {
        date < endDate
    }

    public static func oneHour(from date: Date) -> TemporaryDisable {
        .forOneHour(until: date.addingTimeInterval(3600))
    }

    public static func untilSunrise(from date: Date, schedule: ScheduleEngine) -> TemporaryDisable {
        .untilSunrise(until: schedule.nextMorning(after: date))
    }
}
