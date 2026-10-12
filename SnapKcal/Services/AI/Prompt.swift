import Foundation

enum Prompt {
    static func system(language: String, includeSchema: Bool) -> String {
        let base = """
        You are a nutrition estimator inside a calorie-tracking app. You see one photo of food.
        Estimate what was eaten and its energy content as accurately as possible from the photo.

        Rules:
        - Identify each distinct food/drink item, estimate its portion (grams or common units) using visual cues: plate (~26 cm), cutlery, hands, packaging, glass size.
        - Account for hidden calories typical for the dish: cooking oil, butter, dressings, sauces, sugar in drinks.
        - kcal_total must equal the sum of item kcal (rounded). kcal_low/kcal_high give a realistic range.
        - If the user note says something about portion or ingredients, trust it over the photo.
        - If several people's portions are visible, estimate only one portion unless the note says otherwise.
        - If the image does not show food or drink, set is_food=false, all numbers 0, and explain in description.
        - health_score: 1-10 for nutritional quality of this meal (protein, fiber, vegetables, processing, added sugar, portion size relative to the user's goal).
        - tip: one short, practical, non-judgmental suggestion (max 120 characters), considering the user's goal and remaining kcal today.
        - Write meal_name, description, score_reason and tip in \(language).
        - Respond only with JSON matching the schema.
        """
        guard includeSchema else { return base }
        return base + "\n\nReturn only a JSON object matching this schema:\n" + MealSchema.jsonString
    }

    static func userContext(_ context: AnalysisContext) -> String {
        let goal: String = switch context.goal {
        case .lose: "lose weight"
        case .maintain: "maintain weight"
        case .gain: "gain weight"
        }
        let remaining = context.targetKcal - context.eatenTodayKcal
        var lines = [
            "Goal: \(goal). Daily target: \(context.targetKcal) kcal. Already eaten today: \(context.eatenTodayKcal) kcal. Remaining: \(remaining) kcal.",
            "Local time: \(context.localTime).",
        ]
        if let note = context.userNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            lines.append("User note: \"\(note)\"")
        }
        return lines.joined(separator: "\n")
    }

    static var deviceLanguageName: String {
        let code = Locale.preferredLanguages.first.map { Locale(identifier: $0).language.languageCode?.identifier ?? "en" } ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }
}
