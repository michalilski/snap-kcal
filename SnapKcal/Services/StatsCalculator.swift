import Foundation

struct DayTotal: Equatable, Sendable {
    let dayKey: String
    let kcal: Int
}

struct PeriodSummary: Equatable, Sendable {
    let average: Int
    let max: DayTotal
    let min: DayTotal
    let daysLogged: Int
    let daysElapsed: Int
    let vsTarget: Int
    let onTargetDays: Int
}

struct DayBar: Identifiable, Equatable, Sendable {
    let dayKey: String
    let date: Date
    let kcal: Int?
    let status: DayStatus

    var id: String { dayKey }
}

enum StatsCalculator {
    static func dayTotals(_ meals: [Meal]) -> [String: Int] {
        meals.filter { $0.status == .done }.reduce(into: [:]) { $0[$1.dayKey, default: 0] += $1.kcal }
    }

    static func summary(for range: DateInterval, meals: [Meal], today: Date, target: Int, bonus: [String: Int] = [:], calendar: Calendar = .autoupdatingCurrent) -> PeriodSummary? {
        summary(for: range, totals: dayTotals(meals), today: today, target: target, bonus: bonus, calendar: calendar)
    }

    /// `bonus` holds workout kcal per day, added to that day's target.
    static func summary(for range: DateInterval, totals: [String: Int], today: Date, target: Int, bonus: [String: Int] = [:], calendar: Calendar = .autoupdatingCurrent) -> PeriodSummary? {
        let todayKey = DayKey.key(for: today, calendar: calendar)
        let elapsed = DayKey.keys(in: range, calendar: calendar).filter { $0 < todayKey }
        let counted = elapsed.compactMap { key in totals[key].flatMap { $0 > 0 ? DayTotal(dayKey: key, kcal: $0) : nil } }
        guard let maxDay = counted.max(by: { $0.kcal < $1.kcal }), let minDay = counted.min(by: { $0.kcal < $1.kcal }) else { return nil }
        let average = Int((Double(counted.reduce(0) { $0 + $1.kcal }) / Double(counted.count)).rounded())
        let onTarget = counted.filter { DayStatus.of(total: $0.kcal, target: target + bonus[$0.dayKey, default: 0]) == .onTarget }.count
        let averageBudget = Int((Double(counted.reduce(0) { $0 + target + bonus[$1.dayKey, default: 0] }) / Double(counted.count)).rounded())
        return PeriodSummary(
            average: average, max: maxDay, min: minDay,
            daysLogged: counted.count, daysElapsed: elapsed.count,
            vsTarget: average - averageBudget, onTargetDays: onTarget
        )
    }

    static func bars(for range: DateInterval, totals: [String: Int], today: Date, target: Int, bonus: [String: Int] = [:], calendar: Calendar = .autoupdatingCurrent) -> [DayBar] {
        let todayKey = DayKey.key(for: today, calendar: calendar)
        return DayKey.keys(in: range, calendar: calendar).map { key in
            let status: DayStatus = key > todayKey ? .future : DayStatus.of(total: totals[key], target: target + bonus[key, default: 0])
            return DayBar(dayKey: key, date: DayKey.startOfDay(key, calendar: calendar), kcal: totals[key], status: status)
        }
    }
}
