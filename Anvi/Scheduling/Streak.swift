import Foundation

/// Local calendar day keys (`yyyy-MM-dd`) used by the activity log in `library.json`.
enum DayKey {
    static func string(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Study streak, derived from the daily activity log. A day counts when at least one card
/// was answered. The streak stays alive until the end of the day after the last study day.
struct StreakSummary: Equatable {
    var current: Int
    var longest: Int
    var studiedToday: Bool
    var answersToday: Int

    init(activity: [String: Int], today: Date = .now, calendar: Calendar = .current) {
        let studied = Set(activity.filter { $0.value > 0 }.map(\.key))
        let todayStart = calendar.startOfDay(for: today)
        let todayKey = DayKey.string(for: todayStart, calendar: calendar)

        answersToday = activity[todayKey] ?? 0
        studiedToday = studied.contains(todayKey)

        // Current streak: count back from today, or from yesterday if today has no study yet.
        var day = studiedToday ? todayStart : (calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart)
        var count = 0
        while studied.contains(DayKey.string(for: day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        current = count

        // Longest streak: longest run of consecutive study days.
        let days = studied.compactMap { DayKey.date(from: $0, calendar: calendar) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for date in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == date {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        longest = max(best, current)
    }
}
