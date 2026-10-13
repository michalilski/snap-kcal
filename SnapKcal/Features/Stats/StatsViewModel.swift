import Foundation
import Observation

@Observable
@MainActor
final class StatsViewModel {
    enum Period: Hashable { case week, month }

    var period = Period.week { didSet { load() } }
    var anchor = Date.now
    private(set) var summary: PeriodSummary?
    private(set) var bars: [DayBar] = []
    private(set) var todaySoFar = 0
    private(set) var target = 0
    private(set) var interval: DateInterval?

    private let store: MealStore
    private let workouts: WorkoutCalories?
    private let calendar: Calendar

    init(store: MealStore, workouts: WorkoutCalories? = nil, calendar: Calendar = DayKey.calendar) {
        self.store = store
        self.workouts = workouts
        self.calendar = calendar
    }

    var currentInterval: DateInterval? {
        calendar.dateInterval(of: period == .week ? .weekOfYear : .month, for: anchor)
    }

    var canStepForward: Bool {
        guard let interval else { return false }
        return interval.end <= calendar.startOfDay(for: .now)
    }

    func load() {
        guard let interval = calendar.dateInterval(of: period == .week ? .weekOfYear : .month, for: anchor) else { return }
        self.interval = interval
        let keys = DayKey.keys(in: interval, calendar: calendar)
        let todayKey = DayKey.key(for: .now, calendar: calendar)
        let totals = store.dayTotals(from: keys.first ?? todayKey, to: keys.last ?? todayKey)
        target = store.currentTarget()
        let bonus = workouts?.bonuses ?? [:]
        summary = StatsCalculator.summary(for: interval, totals: totals, today: .now, target: target, bonus: bonus, calendar: calendar)
        bars = StatsCalculator.bars(for: interval, totals: totals, today: .now, target: target, bonus: bonus, calendar: calendar)
        todaySoFar = store.dayTotals(from: todayKey, to: todayKey)[todayKey] ?? 0
    }

    func step(_ delta: Int) {
        guard delta < 0 || canStepForward else { return }
        anchor = calendar.date(byAdding: period == .week ? .weekOfYear : .month, value: delta, to: anchor) ?? anchor
        load()
    }
}
