import Foundation
import Observation

@Observable
@MainActor
final class TodayViewModel {
    var anchor: Date
    var undoCandidate: Meal?
    private var undoTurns: [MealTurn.Snapshot] = []
    var undoDeadline: Date?

    private let store: MealStore
    private let allowsFuture: Bool
    private let onChange: () -> Void

    init(anchor: Date, store: MealStore, allowsFuture: Bool = false, onChange: @escaping () -> Void = {}) {
        self.anchor = anchor
        self.store = store
        self.allowsFuture = allowsFuture
        self.onChange = onChange
    }

    var dayKey: String { DayKey.key(for: anchor) }
    var isToday: Bool { DayKey.calendar.isDateInToday(anchor) }
    var canStepForward: Bool { allowsFuture || dayKey < DayKey.key(for: .now) }
    var targetKcal: Int { store.currentTarget() }

    func step(days: Int) {
        guard days < 0 || canStepForward, let next = DayKey.calendar.date(byAdding: .day, value: days, to: anchor) else { return }
        anchor = next
    }

    func total(for meals: [Meal]) -> Int {
        meals.filter { $0.status == .done }.reduce(0) { $0 + $1.kcal }
    }

    func delete(_ meal: Meal) {
        undoCandidate = meal.detachedCopy()
        undoTurns = meal.orderedTurns.map(\.snapshot)
        let deadline = Date.now.addingTimeInterval(5)
        undoDeadline = deadline
        store.delete(meal)
        onChange()
        Task {
            try? await Task.sleep(for: .seconds(5))
            if undoDeadline == deadline { clearUndo() }
        }
    }

    func undoDelete() {
        guard let copy = undoCandidate else { return }
        store.insert(copy)
        store.restore(undoTurns, to: copy)
        clearUndo()
        onChange()
    }

    private func clearUndo() {
        undoCandidate = nil
        undoDeadline = nil
        undoTurns = []
    }
}
