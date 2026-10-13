import Foundation

struct DetectedItem: Codable, Equatable, Sendable {
    let name: String
    let portion: String
    let kcal: Int
}

struct MealAnalysis: Codable, Equatable, Sendable {
    let isFood: Bool
    let mealName: String
    let description: String
    let items: [DetectedItem]
    let kcalTotal: Int
    let kcalLow: Int
    let kcalHigh: Int
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let healthScore: Int
    let scoreReason: String
    let tip: String
    let confidence: Confidence

    static func decode(_ data: Data) throws -> MealAnalysis {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MealAnalysis.self, from: data)
    }

    static func decode(text: String) throws(AIError) -> MealAnalysis {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            throw .decoding("no JSON object in answer")
        }
        do {
            return try decode(Data(text[start...end].utf8))
        } catch {
            throw .decoding(String(describing: error))
        }
    }

    /// The answer serialized like the model returns it, used as the assistant turn in follow-up requests.
    var schemaJSONString: String {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(self)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    func sanitized() -> MealAnalysis {
        let clampKcal = { (value: Int) in min(max(value, 0), 5000) }
        let total = clampKcal(kcalTotal)
        return MealAnalysis(
            isFood: isFood,
            mealName: String(mealName.prefix(60)),
            description: description,
            items: items.map { DetectedItem(name: $0.name, portion: $0.portion, kcal: clampKcal($0.kcal)) },
            kcalTotal: total,
            kcalLow: min(clampKcal(kcalLow), total),
            kcalHigh: max(clampKcal(kcalHigh), total),
            proteinG: max(proteinG, 0),
            carbsG: max(carbsG, 0),
            fatG: max(fatG, 0),
            healthScore: min(max(healthScore, 1), 10),
            scoreReason: scoreReason,
            tip: tip,
            confidence: confidence
        )
    }
}
