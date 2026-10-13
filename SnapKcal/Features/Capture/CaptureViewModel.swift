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
        case composing
        case analyzing(mealID: PersistentIdentifier)
        case result(mealID: PersistentIdentifier)
        case notFood
        case failed(mealID: PersistentIdentifier, message: String)
    }

    private(set) var phase: Phase = .idle
    private(set) var pendingImage: UIImage?
    private(set) var isRefining = false
    private(set) var refineError: String?
    var note = ""

    private let store: MealStore
    private let analyzer: MealAnalyzer
    private let settings: AppSettings
    private let onChange: () -> Void
    private var targetDay = Date.now
    private var pendingCaptureDate: Date?

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

    var canSubmit: Bool {
        pendingImage != nil || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var currentMeal: Meal? {
        switch phase {
        case .analyzing(let id), .result(let id), .failed(let id, _): store.meal(id: id)
        default: nil
        }
    }

    func snap(for day: Date, source: PhotoSource) {
        targetDay = day
        resetDraft()
        let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
        phase = .picking(source == .camera && cameraAvailable ? .camera : .library)
    }

    func describe(for day: Date) {
        targetDay = day
        resetDraft()
        phase = .composing
    }

    func photoPicked(_ image: UIImage, captureDate: Date?) {
        pendingImage = image
        pendingCaptureDate = captureDate
        phase = .composing
    }

    /// Creates the meal from the composed photo and/or text and starts the first estimate.
    func submit() {
        guard canSubmit else { return }
        let meal = Meal(eatenAt: eatenAt(captureDate: pendingCaptureDate), provider: settings.activeProvider, modelId: settings.modelId(for: settings.activeProvider) ?? "")
        store.insert(meal)
        onChange()
        let image = pendingImage
        let text = note
        resetDraft()
        let id = meal.persistentModelID
        phase = .analyzing(mealID: id)
        Task {
            let outcome = await analyzer.send(to: meal, image: image, text: text)
            initialFinished(meal: meal, id: id, outcome: outcome)
        }
    }

    /// Adds a follow-up message about the current meal, e.g. "there are also 2 slices of ham" plus a packaging photo.
    func sendFollowUp(image: UIImage?, text: String) {
        guard let meal = currentMeal, !isRefining else { return }
        guard image != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRefining = true
        refineError = nil
        Task {
            let outcome = await analyzer.send(to: meal, image: image, text: text)
            refineFinished(outcome)
        }
    }

    func retryFollowUp() {
        guard let meal = currentMeal, !isRefining else { return }
        isRefining = true
        refineError = nil
        Task { refineFinished(await analyzer.rerun(meal)) }
    }

    func discardFollowUp() {
        guard let meal = currentMeal else { return }
        analyzer.discardPendingTurn(of: meal)
        refineError = nil
        onChange()
    }

    func retake() {
        snap(for: targetDay, source: .camera)
    }

    func cancelPicking() {
        resetDraft()
        phase = .idle
    }

    func retry(with model: AIModel? = nil) {
        guard let meal = currentMeal else { return }
        restartInitial(meal: meal, modelOverride: model)
    }

    func retry(meal: Meal) {
        restartInitial(meal: meal, modelOverride: nil)
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
        if let meal = currentMeal { analyzer.discardPendingTurn(of: meal) }
        store.save()
        onChange()
        refineError = nil
        phase = .idle
    }

    func discard() {
        if let meal = currentMeal { store.delete(meal) }
        onChange()
        refineError = nil
        phase = .idle
    }

    func dismissWhileAnalyzing() {
        phase = .idle
    }

    func sheetDismissed() {
        switch phase {
        case .analyzing: dismissWhileAnalyzing()
        case .result: finish()
        case .composing: cancelPicking()
        case .notFood, .failed: phase = .idle
        default: break
        }
    }

    private func restartInitial(meal: Meal, modelOverride: AIModel?) {
        let id = meal.persistentModelID
        phase = .analyzing(mealID: id)
        Task {
            let outcome = await analyzer.rerun(meal, modelOverride: modelOverride)
            initialFinished(meal: meal, id: id, outcome: outcome)
        }
    }

    private func initialFinished(meal: Meal, id: PersistentIdentifier, outcome: TurnOutcome) {
        let isActive = phase == .analyzing(mealID: id)
        switch outcome {
        case .notFood:
            store.delete(meal)
            if isActive { phase = .notFood }
        case .estimated:
            if isActive { phase = .result(mealID: id) }
        case .failed(let message):
            if isActive { phase = .failed(mealID: id, message: message) }
        }
        onChange()
        if isActive { Haptics(settings: settings).notify(success: outcome == .estimated) }
    }

    private func refineFinished(_ outcome: TurnOutcome) {
        isRefining = false
        switch outcome {
        case .estimated: refineError = nil
        case .notFood: refineError = String(localized: "That doesn't look like food, so the estimate is unchanged.")
        case .failed(let message): refineError = message
        }
        onChange()
        Haptics(settings: settings).notify(success: outcome == .estimated)
    }

    private func persistEdit() {
        if settings.autoSave { store.save() }
        onChange()
    }

    private func resetDraft() {
        note = ""
        pendingImage = nil
        pendingCaptureDate = nil
        refineError = nil
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
