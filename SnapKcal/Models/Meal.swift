import Foundation
import SwiftData

@Model
final class Meal {
    #Index<Meal>([\.dayKey], [\.eatenAt])

    @Attribute(.unique) var id: UUID
    var dayKey: String
    var eatenAt: Date
    var createdAt: Date
    var status: MealStatus
    var errorMessage: String?

    var name: String
    var summary: String
    var kcal: Int
    var kcalEstimated: Int
    var kcalLow: Int
    var kcalHigh: Int
    var kcalSource: KcalSource = KcalSource.model
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var healthScore: Int
    var scoreReason: String
    var tip: String
    var confidence: Confidence
    var itemsJSON: Data
    var userNote: String?
    var portionMultiplier: Double

    var provider: Provider
    var modelId: String
    var inputTokens: Int?
    var outputTokens: Int?

    @Attribute(.externalStorage) var photo: Data?
    @Attribute(.externalStorage) var thumbnail: Data?

    init(eatenAt: Date, provider: Provider = .openai, modelId: String = "") {
        id = UUID()
        dayKey = DayKey.key(for: eatenAt)
        self.eatenAt = eatenAt
        createdAt = .now
        status = .analyzing
        name = ""
        summary = ""
        kcal = 0
        kcalEstimated = 0
        kcalLow = 0
        kcalHigh = 0
        proteinG = 0
        carbsG = 0
        fatG = 0
        healthScore = 0
        scoreReason = ""
        tip = ""
        confidence = .medium
        itemsJSON = Data("[]".utf8)
        portionMultiplier = 1
        self.provider = provider
        self.modelId = modelId
    }

    var items: [DetectedItem] {
        (try? JSONDecoder().decode([DetectedItem].self, from: itemsJSON)) ?? []
    }

    func move(to date: Date) {
        eatenAt = date
        dayKey = DayKey.key(for: date)
    }

    func apply(_ result: AnalysisResult) {
        let analysis = result.analysis
        name = analysis.mealName
        summary = analysis.description
        kcalEstimated = analysis.kcalTotal
        kcal = analysis.kcalTotal
        kcalSource = .model
        portionMultiplier = 1
        kcalLow = analysis.kcalLow
        kcalHigh = analysis.kcalHigh
        proteinG = analysis.proteinG
        carbsG = analysis.carbsG
        fatG = analysis.fatG
        healthScore = analysis.healthScore
        scoreReason = analysis.scoreReason
        tip = analysis.tip
        confidence = analysis.confidence
        itemsJSON = (try? JSONEncoder().encode(analysis.items)) ?? Data("[]".utf8)
        provider = result.provider
        modelId = result.modelId
        inputTokens = result.inputTokens
        outputTokens = result.outputTokens
        errorMessage = nil
        status = .done
    }

    func setPortion(_ multiplier: Double) {
        portionMultiplier = multiplier
        kcal = Int((Double(kcalEstimated) * multiplier).rounded())
        kcalSource = .portion
    }

    func setManualKcal(_ value: Int) {
        kcal = min(max(value, 0), 9999)
        kcalSource = .manual
    }

    func resetToEstimate() {
        kcal = kcalEstimated
        portionMultiplier = 1
        kcalSource = .model
    }

    func detachedCopy() -> Meal {
        let copy = Meal(eatenAt: eatenAt, provider: provider, modelId: modelId)
        copy.id = id
        copy.createdAt = createdAt
        copy.status = status
        copy.errorMessage = errorMessage
        copy.name = name
        copy.summary = summary
        copy.kcal = kcal
        copy.kcalEstimated = kcalEstimated
        copy.kcalLow = kcalLow
        copy.kcalHigh = kcalHigh
        copy.kcalSource = kcalSource
        copy.proteinG = proteinG
        copy.carbsG = carbsG
        copy.fatG = fatG
        copy.healthScore = healthScore
        copy.scoreReason = scoreReason
        copy.tip = tip
        copy.confidence = confidence
        copy.itemsJSON = itemsJSON
        copy.userNote = userNote
        copy.portionMultiplier = portionMultiplier
        copy.inputTokens = inputTokens
        copy.outputTokens = outputTokens
        copy.photo = photo
        copy.thumbnail = thumbnail
        return copy
    }
}
