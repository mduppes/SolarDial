import Foundation

/// When to post the bedtime notification: once, in the first 15 minutes after bedtime.
/// The window means launching or waking the Mac at 3 a.m. doesn't fire a stale reminder.
public enum BedtimeReminder {
    public static let window: Double = 15

    public static func shouldRemind(at date: Date, schedule: ScheduleEngine, lastReminder: Date?) -> Bool {
        guard schedule.minutesSinceBedtime(at: date) < window else { return false }
        if let lastReminder, date.timeIntervalSince(lastReminder) < 12 * 3600 { return false }
        return true
    }

    /// "You're waking up in 8½ hours." Rounded to the nearest half hour.
    public static func message(at date: Date, schedule: ScheduleEngine) -> String {
        let halfHours = Int((schedule.minutesUntilWake(at: date) / 30).rounded())
        let hours = halfHours / 2
        let half = halfHours % 2 == 1 ? "½" : ""
        return "You're waking up in \(hours)\(half) hours."
    }
}
