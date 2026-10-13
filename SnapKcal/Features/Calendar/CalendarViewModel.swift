import Foundation
import Observation

struct CalendarCell: Identifiable, Equatable {
    let id: Int
    let dayKey: String?
    let dayNumber: Int?
    let totalKcal: Int?
    let status: DayStatus
}

@Observable
@MainActor
final class CalendarViewModel {
    var month: Date
    private(set) var cells: [CalendarCell] = []

    private let store: MealStore
    private let workouts: WorkoutCalories?
    private let calendar: Calendar

    init(store: MealStore, workouts: WorkoutCalories? = nil, now: Date = .now, calendar: Calendar = DayKey.calendar) {
        self.store = store
        self.workouts = workouts
        self.calendar = calendar
        month = calendar.dateInterval(of: .month, for: now)?.start ?? now
    }

    var weekdaySymbols: [String] {
        var english = calendar
        english.locale = AppLocale.current
        let symbols = english.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: .now, toGranularity: .month)
    }

    func load() {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return }
        let keys = DayKey.keys(in: interval, calendar: calendar)
        guard let first = keys.first, let last = keys.last else { return }
        let totals = store.dayTotals(from: first, to: last)
        cells = Self.makeCells(month: interval.start, keys: keys, totals: totals, target: store.currentTarget(), bonus: workouts?.bonuses ?? [:], today: .now, calendar: calendar)
    }

    func step(months: Int) {
        month = calendar.date(byAdding: .month, value: months, to: month) ?? month
        load()
    }

    func jumpToToday() {
        month = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        load()
    }

    var monthInterval: DateInterval? {
        calendar.dateInterval(of: .month, for: month)
    }

    static func makeCells(month: Date, keys: [String], totals: [String: Int], target: Int, bonus: [String: Int] = [:], today: Date, calendar: Calendar) -> [CalendarCell] {
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let todayKey = DayKey.key(for: today, calendar: calendar)
        return (0..<42).map { index in
            let dayIndex = index - leading
            guard keys.indices.contains(dayIndex) else {
                return CalendarCell(id: index, dayKey: nil, dayNumber: nil, totalKcal: nil, status: .empty)
            }
            let key = keys[dayIndex]
            let status: DayStatus = key > todayKey ? .future : DayStatus.of(total: totals[key], target: target + bonus[key, default: 0])
            return CalendarCell(id: index, dayKey: key, dayNumber: dayIndex + 1, totalKcal: totals[key], status: status)
        }
    }
}
