import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class CaptureViewModel {
    enum Phase: Equatable {
        case idle
        case picking(PhotoSource)
        case analyzing(mealID: PersistentIdentifier)
        case result(mealID: PersistentIdentifier)
        case notFood
        case failed(mealID: PersistentIdentifier, message: String)
    }

    private(set) var phase: Phase = .idle
    var note = ""

    private let store: MealStore
    private let analyzer: MealAnalyzer
    private let settings: AppSettings
    private let onChange: () -> Void
    private var targetDay = Date.now

    init(store: MealStore, analyzer: MealAnalyzer, settings: AppSettings, onChange: @escaping () -> Void = {}) {
        self.store = store
        self.analyzer = analyzer
        self.settings = settings
        self.onChange = onChange
    }

    var isSheetPresented: Bool {
        switch phase {
        case .idle, .picking: false
        default: true
        }
    }

    var isPickingCamera: Bool { phase == .picking(.camera) }
    var isPickingLibrary: Bool { phase == .picking(.library) }

    var currentMeal: Meal? {
        switch phase {
        case .analyzing(let id), .result(let id), .failed(let id, _): store.meal(id: id)
        default: nil
        }
    }

    func snap(for day: Date, source: PhotoSource) {
        targetDay = day
        note = ""
        let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        phase = .picking(source == .camera && cameraAvailable ? .camera : .library)
    }

    func photoPicked(_ image: UIImage, captureDate: Date?) {
        let meal = Meal(eatenAt: eatenAt(captureDate: captureDate), provider: settings.activeProvider, modelId: settings.modelId(for: settings.activeProvider) ?? "")
        store.insert(meal)
        onChange()
        startAnalysis(meal: meal, image: image, modelOverride: nil)
    }

    func retake() {
        snap(for: targetDay, source: .camera)
    }

    func cancelPicking() {
        phase = .idle
    }

    func retry(with model: AIModel? = nil) {
        guard let meal = currentMeal else { return }
        startAnalysis(meal: meal, image: nil, modelOverride: model)
    }

    func retry(meal: Meal) {
        note = meal.userNote ?? ""
        startAnalysis(meal: meal, image: nil, modelOverride: nil)
    }

    func reEstimate() {
        retry()
    }

    func setPortion(_ multiplier: Double) {
        currentMeal?.setPortion(multiplier)
        persistEdit()
    }

    func setManualKcal(_ kcal: Int) {
        currentMeal?.setManualKcal(kcal)
        persistEdit()
    }

    func resetToEstimate() {
        currentMeal?.resetToEstimate()
        persistEdit()
    }

    func finish() {
        store.save()
        onChange()
        phase = .idle
    }

    func discard() {
        if let meal = currentMeal { store.delete(meal) }
        onChange()
        phase = .idle
    }

    func dismissWhileAnalyzing() {
        phase = .idle
    }

    func sheetDismissed() {
        switch phase {
        case .analyzing: dismissWhileAnalyzing()
        case .result: finish()
        case .notFood, .failed: phase = .idle
        default: break
        }
    }

    private func startAnalysis(meal: Meal, image: UIImage?, modelOverride: AIModel?) {
        let id = meal.persistentModelID
        phase = .analyzing(mealID: id)
        let note = note
        Task {
            await analyzer.run(meal: meal, image: image, note: note, modelOverride: modelOverride)
            analysisFinished(meal: meal, id: id)
        }
    }

    private func analysisFinished(meal: Meal, id: PersistentIdentifier) {
        let isNotFood = meal.status == .failed && meal.errorMessage == MealAnalyzer.notFoodMarker
        let isActive = phase == .analyzing(mealID: id)
        if isNotFood {
            store.delete(meal)
            if isActive { phase = .notFood }
        } else if isActive {
            phase = meal.status == .done ? .result(mealID: id) : .failed(mealID: id, message: meal.errorMessage ?? "")
        }
        onChange()
        if isActive { Haptics(settings: settings).notify(success: meal.status == .done && !isNotFood) }
    }

    private func persistEdit() {
        if settings.autoSave { store.save() }
        onChange()
    }

    private func eatenAt(captureDate: Date?) -> Date {
        let calendar = DayKey.calendar
        if let captureDate, captureDate <= .now, Date.now.timeIntervalSince(captureDate) < 30 * 24 * 3600 {
            return captureDate
        }
        if calendar.isDateInToday(targetDay) { return .now }
        return DayKey.atCurrentTime(on: calendar.startOfDay(for: targetDay))
    }
}
