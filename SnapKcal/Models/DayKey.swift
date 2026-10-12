import Foundation

enum DayKey {
    static var calendar: Calendar { .autoupdatingCurrent }

    private static func formatter(_ calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func key(for date: Date, calendar: Calendar = calendar) -> String {
        formatter(calendar).string(from: date)
    }

    static func startOfDay(_ key: String, calendar: Calendar = calendar) -> Date {
        formatter(calendar).date(from: key).map { calendar.startOfDay(for: $0) } ?? calendar.startOfDay(for: .now)
    }

    static func keys(in interval: DateInterval, calendar: Calendar = calendar) -> [String] {
        var keys: [String] = []
        var day = calendar.startOfDay(for: interval.start)
        while day < interval.end {
            keys.append(key(for: day, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return keys
    }

    static func atCurrentTime(on day: Date, now: Date = .now, calendar: Calendar = calendar) -> Date {
        let time = calendar.dateComponents([.hour, .minute, .second], from: now)
        return calendar.date(bySettingHour: time.hour ?? 12, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
    }
}
