import Foundation
import SwiftData

@MainActor
final class MealStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        return try ModelContainer(
            for: Meal.self, MealTurn.self, UserProfile.self, WeightEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    func insert(_ meal: Meal) {
        context.insert(meal)
        save()
    }

    func appendTurn(to meal: Meal, text: String?, photo: Data?) -> MealTurn {
        let turn = MealTurn(index: (meal.turns.map(\.index).max() ?? -1) + 1, text: text, photo: photo)
        context.insert(turn)
        turn.meal = meal
        save()
        return turn
    }

    func restore(_ snapshots: [MealTurn.Snapshot], to meal: Meal) {
        for snapshot in snapshots {
            let turn = MealTurn(snapshot: snapshot)
            context.insert(turn)
            turn.meal = meal
        }
        save()
    }

    func delete(_ meal: Meal) {
        context.delete(meal)
        save()
    }

    func save() {
        try? context.save()
    }

    func meal(id: PersistentIdentifier) -> Meal? {
        context.model(for: id) as? Meal
    }

    func fetchMeals(dayKey: String) -> [Meal] {
        let key = dayKey
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.dayKey == key }, sortBy: [SortDescriptor(\.eatenAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchMeals(from startKey: String, to endKey: String) -> [Meal] {
        let start = startKey
        let end = endKey
        let descriptor = FetchDescriptor<Meal>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey <= end }, sortBy: [SortDescriptor(\.eatenAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func allMeals() -> [Meal] {
        (try? context.fetch(FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.eatenAt)]))) ?? []
    }

    func dayTotals(from startKey: String, to endKey: String) -> [String: Int] {
        fetchMeals(from: startKey, to: endKey)
            .filter { $0.status == .done }
            .reduce(into: [:]) { $0[$1.dayKey, default: 0] += $1.kcal }
    }

    func existingProfile() -> UserProfile? {
        try? context.fetch(FetchDescriptor<UserProfile>()).first
    }

    func profile() -> UserProfile {
        if let profile = existingProfile() { return profile }
        let profile = UserProfile(draft: ProfileDraft())
        context.insert(profile)
        save()
        return profile
    }

    func saveProfile(_ draft: ProfileDraft) {
        let profile = profile()
        let weightChanged = profile.weightKg != draft.weightKg
        profile.update(from: draft)
        if weightChanged { appendWeight(draft.weightKg) }
        save()
    }

    func appendWeight(_ kg: Double) {
        context.insert(WeightEntry(kg: kg))
        save()
    }

    func weightCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<WeightEntry>())) ?? 0
    }

    func currentTarget() -> Int {
        NutritionCalculator.target(for: existingProfile())
    }

    func recoverStuckMeals(now: Date = .now) {
        let descriptor = FetchDescriptor<Meal>()
        let stuck = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.status == .analyzing && now.timeIntervalSince($0.createdAt) > 120 }
        for meal in stuck {
            meal.status = .failed
            meal.errorMessage = String(localized: "Interrupted — tap to retry")
        }
        if !stuck.isEmpty { save() }
    }

    func deleteAll() {
        try? context.delete(model: Meal.self)
        try? context.delete(model: WeightEntry.self)
        try? context.delete(model: UserProfile.self)
        save()
    }
}
