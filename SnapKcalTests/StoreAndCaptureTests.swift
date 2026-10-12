import Foundation
import Testing
import UIKit
@testable import SnapKcal

@MainActor
struct StoreAndCaptureTests {
    @Test func dayKeyAndMidnightBoundary() {
        let calendar = TestCalendar.make()
        #expect(DayKey.key(for: TestCalendar.date("2026-10-12 23:59", calendar: calendar), calendar: calendar) == "2026-10-12")
        #expect(DayKey.key(for: TestCalendar.date("2026-10-13 00:00", calendar: calendar), calendar: calendar) == "2026-10-13")
    }

    @Test func dayTotalsOnlyCountDone() {
        let store = TestStore.make()
        let done = Meal(eatenAt: .now)
        done.status = .done
        done.kcal = 400
        let analyzing = Meal(eatenAt: .now)
        analyzing.kcal = 300
        store.insert(done)
        store.insert(analyzing)
        let key = DayKey.key(for: .now)
        #expect(store.dayTotals(from: key, to: key) == [key: 400])
    }

    @Test func moveMealUpdatesDayKey() {
        let meal = Meal(eatenAt: .now)
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        meal.move(to: lastWeek)
        #expect(meal.dayKey == DayKey.key(for: lastWeek))
    }

    @Test func portionAndManualKcal() {
        let meal = Meal(eatenAt: .now)
        meal.kcalEstimated = 600
        meal.kcal = 600
        meal.setPortion(1.5)
        #expect(meal.kcal == 900)
        #expect(meal.kcalSource == .portion)
        meal.setManualKcal(720)
        #expect(meal.kcal == 720)
        #expect(meal.kcalSource == .manual)
        meal.resetToEstimate()
        #expect(meal.kcal == 600)
        #expect(meal.kcalSource == .model)
    }

    @Test func recoverStuckMeals() {
        let store = TestStore.make()
        let meal = Meal(eatenAt: .now)
        meal.createdAt = Date.now.addingTimeInterval(-300)
        store.insert(meal)
        store.recoverStuckMeals()
        #expect(meal.status == .failed)
    }

    @Test func profileSaveAppendsWeight() {
        let store = TestStore.make()
        var draft = ProfileDraft()
        draft.weightKg = 82.5
        store.saveProfile(draft)
        #expect(store.existingProfile()?.weightKg == 82.5)
        #expect(store.weightCount() == 1)
    }

    @Test func calendarGridHas42CellsWithMondayStart() {
        let calendar = TestCalendar.make()
        let month = TestCalendar.date("2026-10-01", calendar: calendar)
        let keys = DayKey.keys(in: calendar.dateInterval(of: .month, for: month)!, calendar: calendar)
        let cells = CalendarViewModel.makeCells(month: month, keys: keys, totals: ["2026-10-05": 2000], target: 2000, today: TestCalendar.date("2026-10-12"), calendar: calendar)
        #expect(cells.count == 42)
        #expect(cells.prefix(3).allSatisfy { $0.dayKey == nil })
        #expect(cells[3].dayNumber == 1)
        #expect(cells.first { $0.dayKey == "2026-10-05" }?.status == .onTarget)
        #expect(cells.first { $0.dayKey == "2026-10-20" }?.status == .future)
    }

    @Test func undoRestoresDeletedMeal() {
        let store = TestStore.make()
        let meal = Meal(eatenAt: .now)
        meal.name = "Soup"
        meal.status = .done
        store.insert(meal)
        let viewModel = TodayViewModel(anchor: .now, store: store)
        viewModel.delete(meal)
        #expect(store.fetchMeals(dayKey: DayKey.key(for: .now)).isEmpty)
        viewModel.undoDelete()
        #expect(store.fetchMeals(dayKey: DayKey.key(for: .now)).first?.name == "Soup")
    }

    private func makeCapture(store: MealStore) -> CaptureViewModel {
        let settings = TestStore.settings()
        let providers: [Provider: any AIProvider] = [.openai: MockProvider(provider: .openai, delay: .milliseconds(10))]
        let catalog = ModelCatalog(providers: providers, directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let analyzer = MealAnalyzer(providers: providers, keys: KeyResolver { _ in "k" }, settings: settings, store: store, catalog: catalog)
        return CaptureViewModel(store: store, analyzer: analyzer, settings: settings)
    }

    private func waitWhileAnalyzing(_ capture: CaptureViewModel) async {
        for _ in 0..<200 {
            if case .analyzing = capture.phase { try? await Task.sleep(for: .milliseconds(10)) } else { return }
        }
    }

    @Test func captureLoopSavesMeal() async {
        let store = TestStore.make()
        let capture = makeCapture(store: store)
        capture.snap(for: .now, source: .library)
        capture.photoPicked(LibraryPhotoLoader.sampleMealImage(), captureDate: nil)
        await waitWhileAnalyzing(capture)
        guard case .result = capture.phase else { Issue.record("expected result, got \(capture.phase)"); return }
        let meal = capture.currentMeal
        #expect(meal?.kcal == 600)
        #expect(meal?.status == .done)
        #expect(meal?.thumbnail != nil)
        capture.setPortion(0.5)
        #expect(meal?.kcal == 300)
        capture.finish()
        #expect(capture.phase == .idle)
    }

    @Test func captureNotFoodDeletesMeal() async {
        let store = TestStore.make()
        let capture = makeCapture(store: store)
        capture.snap(for: .now, source: .library)
        capture.note = "notfood"
        capture.photoPicked(LibraryPhotoLoader.sampleMealImage(), captureDate: nil)
        await waitWhileAnalyzing(capture)
        #expect(capture.phase == .notFood)
        #expect(store.allMeals().isEmpty)
    }

    @Test func captureFailureKeepsRetryableMeal() async {
        let store = TestStore.make()
        let capture = makeCapture(store: store)
        capture.snap(for: .now, source: .library)
        capture.note = "fail"
        capture.photoPicked(LibraryPhotoLoader.sampleMealImage(), captureDate: nil)
        await waitWhileAnalyzing(capture)
        guard case .failed = capture.phase else { Issue.record("expected failed, got \(capture.phase)"); return }
        #expect(store.allMeals().first?.status == .failed)
        #expect(store.allMeals().first?.photo != nil)
        capture.note = ""
        capture.retry()
        await waitWhileAnalyzing(capture)
        #expect(store.allMeals().first?.status == .done)
    }

    @Test func pastDayCaptureUsesThatDay() async {
        let store = TestStore.make()
        let capture = makeCapture(store: store)
        let lastTuesday = Calendar.current.date(byAdding: .day, value: -6, to: .now)!
        capture.snap(for: lastTuesday, source: .library)
        capture.photoPicked(LibraryPhotoLoader.sampleMealImage(), captureDate: nil)
        await waitWhileAnalyzing(capture)
        #expect(store.allMeals().first?.dayKey == DayKey.key(for: lastTuesday))
    }

    @Test func exportFormats() throws {
        let meal = Meal(eatenAt: .now)
        meal.name = "Pierogi, \"ruskie\""
        meal.kcal = 450
        meal.userNote = "zażółć"
        let csv = ExportService.csv(meals: [meal])
        #expect(csv.starts(with: [0xEF, 0xBB, 0xBF]))
        let text = String(decoding: csv.dropFirst(3), as: UTF8.self)
        #expect(text.hasPrefix("date,time,name,kcal,kcal_estimated"))
        #expect(text.contains("\"Pierogi, \"\"ruskie\"\"\""))
        #expect(text.contains("zażółć"))
        let json = try JSONSerialization.jsonObject(with: ExportService.json(meals: [meal], profile: nil)) as? [String: Any]
        #expect((json?["meals"] as? [[String: Any]])?.first?["kcal"] as? Int == 450)
        #expect((json?["meals"] as? [[String: Any]])?.first?["photo"] == nil)
    }
}
