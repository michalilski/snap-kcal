import Foundation
import HealthKit
import Observation

protocol ActivitySource: Sendable {
    func requestAccess() async
    /// Active kcal of workouts that started in the interval, summed per day key.
    func workoutKcal(in interval: DateInterval) async -> [String: Int]
}

final class HealthKitActivitySource: ActivitySource, @unchecked Sendable {
    private let store = HKHealthStore()
    private let energy = HKQuantityType(.activeEnergyBurned)

    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), energy])
    }

    func workoutKcal(in interval: DateInterval) async -> [String: Int] {
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
        guard let workouts = try? await descriptor.result(for: store) else { return [:] }
        return workouts.reduce(into: [:]) { totals, workout in
            let kcal = workout.statistics(for: energy)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            totals[DayKey.key(for: workout.startDate), default: 0] += Int(kcal.rounded())
        }
    }
}

struct MockActivitySource: ActivitySource {
    var todayKcal = 320

    func requestAccess() async {}

    func workoutKcal(in interval: DateInterval) async -> [String: Int] {
        interval.contains(.now) ? [DayKey.key(for: .now): todayKcal] : [:]
    }
}

/// Cached per-day workout calories that extend the daily kcal budget.
@Observable
@MainActor
final class WorkoutCalories {
    private(set) var byDay: [String: Int] = [:]

    @ObservationIgnored private let source: any ActivitySource
    @ObservationIgnored private let settings: AppSettings

    init(source: any ActivitySource, settings: AppSettings) {
        self.source = source
        self.settings = settings
    }

    func kcal(for dayKey: String) -> Int {
        settings.useWorkouts ? byDay[dayKey] ?? 0 : 0
    }

    var bonuses: [String: Int] {
        settings.useWorkouts ? byDay : [:]
    }

    func requestAccessIfNeeded() async {
        guard settings.useWorkouts, !settings.healthAccessRequested else { return }
        await source.requestAccess()
        settings.healthAccessRequested = true
    }

    func requestAccess() async {
        await source.requestAccess()
        settings.healthAccessRequested = true
    }

    func refresh(_ interval: DateInterval) async {
        guard settings.useWorkouts else { return }
        let totals = await source.workoutKcal(in: interval)
        for key in DayKey.keys(in: interval) { byDay[key] = totals[key] }
    }

    func refresh(dayKey: String) async {
        let start = DayKey.startOfDay(dayKey)
        guard let end = DayKey.calendar.date(byAdding: .day, value: 1, to: start) else { return }
        await refresh(DateInterval(start: start, end: end))
    }
}
