import Foundation

enum Prompt {
    static func system(language: String, includeSchema: Bool) -> String {
        let base = """
        You are a nutrition estimator inside a calorie-tracking app. You get a photo of food, a text description, or both.
        Estimate what was eaten and its energy content as accurately as possible.

        Rules:
        - Identify each distinct food/drink item, estimate its portion (grams or common units) using visual cues: plate (~26 cm), cutlery, hands, packaging, glass size.
        - Account for hidden calories typical for the dish: cooking oil, butter, dressings, sauces, sugar in drinks.
        - kcal_total must equal the sum of item kcal (rounded). kcal_low/kcal_high give a realistic range.
        - If the user's text says something about portion or ingredients, trust it over the photo.
        - The user may write in any language (often Polish) and mention local products, brands or shops (e.g. "grahamka z Żabki" = a graham bread roll from the Żabka convenience store). Understand them and use typical nutrition values for those products.
        - Without a photo, estimate from the text alone using a typical single serving.
        - If several people's portions are visible, estimate only one portion unless the text says otherwise.
        - The conversation can continue: later messages add photos (e.g. packaging) or details about the SAME meal. Always return the full updated estimate for the whole meal including everything said so far, not only the new part.
        - If the input does not show or describe food or drink, set is_food=false, all numbers 0, and explain in description.
        - health_score: 1-10 for nutritional quality of this meal (protein, fiber, vegetables, processing, added sugar, portion size relative to the user's goal).
        - tip: one short, practical, non-judgmental suggestion (max 120 characters), considering the user's goal and remaining kcal today.
        - Always write meal_name, description, item names, score_reason and tip in \(language), whatever language the user writes in.
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
        let workouts = context.workoutKcal > 0 ? " (includes \(context.workoutKcal) kcal burned in today's workouts)" : ""
        return [
            "Goal: \(goal). Daily target: \(context.targetKcal) kcal\(workouts). Already eaten today: \(context.eatenTodayKcal) kcal. Remaining: \(remaining) kcal.",
            "Local time: \(context.localTime).",
        ].joined(separator: "\n")
    }

    static func userText(for turn: ConversationTurn, isFirst: Bool, context: AnalysisContext) -> String {
        var lines: [String] = []
        if isFirst {
            lines.append(userContext(context))
            if let text = turn.trimmedText { lines.append("User note: \"\(text)\"") }
            if turn.imageJPEG == nil { lines.append("No photo, estimate from the description.") }
        } else {
            lines.append("Follow-up about the same meal.")
            if let text = turn.trimmedText { lines.append("User says: \"\(text)\"") }
            if turn.imageJPEG != nil { lines.append("An additional photo is attached.") }
            lines.append("Return the full updated estimate for the whole meal.")
        }
        return lines.joined(separator: "\n")
    }

    static var appLanguageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: "en").localizedString(forLanguageCode: code) ?? "English"
    }
}
