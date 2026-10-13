import Foundation
import Testing
@testable import SnapKcal

struct StatsCalculatorTests {
    let calendar = TestCalendar.make()

    private func week(of day: String) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: TestCalendar.date(day, calendar: calendar))!
    }

    @Test func emptyPeriod() {
        #expect(StatsCalculator.summary(for: week(of: "2026-10-07"), totals: [:], today: TestCalendar.date("2026-10-20"), target: 2000, calendar: calendar) == nil)
    }

    @Test func singleDay() {
        let summary = StatsCalculator.summary(for: week(of: "2026-10-07"), totals: ["2026-10-06": 1800], today: TestCalendar.date("2026-10-20"), target: 2000, calendar: calendar)
        #expect(summary?.average == 1800)
        #expect(summary?.max == DayTotal(dayKey: "2026-10-06", kcal: 1800))
        #expect(summary?.min == DayTotal(dayKey: "2026-10-06", kcal: 1800))
        #expect(summary?.daysLogged == 1)
        #expect(summary?.daysElapsed == 7)
        #expect(summary?.vsTarget == -200)
        #expect(summary?.onTargetDays == 1)
    }

    @Test func todayExcluded() {
        let totals = ["2026-10-12": 1000, "2026-10-13": 3000, "2026-10-14": 500]
        let summary = StatsCalculator.summary(for: week(of: "2026-10-14"), totals: totals, today: TestCalendar.date("2026-10-14 13:00"), target: 2000, calendar: calendar)
        #expect(summary?.daysLogged == 2)
        #expect(summary?.daysElapsed == 2)
        #expect(summary?.average == 2000)
        #expect(summary?.max.kcal == 3000)
        #expect(summary?.min.kcal == 1000)
    }

    @Test func monthWith31Days() {
        let interval = calendar.dateInterval(of: .month, for: TestCalendar.date("2026-10-15"))!
        #expect(DayKey.keys(in: interval, calendar: calendar).count == 31)
        let bars = StatsCalculator.bars(for: interval, totals: ["2026-10-31": 1900], today: TestCalendar.date("2026-11-05"), target: 2000, calendar: calendar)
        #expect(bars.count == 31)
        #expect(bars.last?.status == .onTarget)
    }

    @Test func dstWeekHasSevenDays() {
        let interval = week(of: "2026-10-25")
        let keys = DayKey.keys(in: interval, calendar: calendar)
        #expect(keys == ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"])
    }

    @Test func weekStartsOnMondayInPoland() {
        #expect(DayKey.key(for: week(of: "2026-10-14").start, calendar: calendar) == "2026-10-12")
    }

    @Test func emptyDaysSkipped() {
        let totals = ["2026-10-05": 2000, "2026-10-07": 1000]
        let summary = StatsCalculator.summary(for: week(of: "2026-10-07"), totals: totals, today: TestCalendar.date("2026-10-20"), target: 2000, calendar: calendar)
        #expect(summary?.average == 1500)
        #expect(summary?.daysLogged == 2)
    }

    @Test func workoutBonusRaisesDailyTarget() {
        let totals = ["2026-10-05": 2300, "2026-10-06": 2300]
        let bonus = ["2026-10-05": 400]
        let summary = StatsCalculator.summary(for: week(of: "2026-10-07"), totals: totals, today: TestCalendar.date("2026-10-20"), target: 2000, bonus: bonus, calendar: calendar)
        #expect(summary?.onTargetDays == 1)
        #expect(summary?.vsTarget == 100)
        let bars = StatsCalculator.bars(for: week(of: "2026-10-07"), totals: totals, today: TestCalendar.date("2026-10-20"), target: 2000, bonus: bonus, calendar: calendar)
        #expect(bars.first { $0.dayKey == "2026-10-05" }?.status == .onTarget)
        #expect(bars.first { $0.dayKey == "2026-10-06" }?.status == .over)
    }

    @Test func onlyDoneMealsCount() {
        let done = Meal(eatenAt: .now)
        done.status = .done
        done.kcal = 500
        let failed = Meal(eatenAt: .now)
        failed.status = .failed
        failed.kcal = 900
        #expect(StatsCalculator.dayTotals([done, failed]) == [done.dayKey: 500])
    }

    @Test(arguments: [(nil, DayStatus.empty), (1700, .under), (1900, .onTarget), (2200, .onTarget), (2300, .over)])
    func dayStatus(total: Int?, expected: DayStatus) {
        #expect(DayStatus.of(total: total, target: 2000) == expected)
    }
}
