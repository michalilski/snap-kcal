import Foundation

enum ExportService {
    static func json(meals: [Meal], profile: UserProfile?, now: Date = .now) -> Data {
        let iso = ISO8601DateFormatter()
        let mealObjects: [[String: Any]] = meals.map { meal in
            [
                "id": meal.id.uuidString, "dayKey": meal.dayKey, "eatenAt": iso.string(from: meal.eatenAt),
                "name": meal.name, "kcal": meal.kcal, "kcalEstimated": meal.kcalEstimated,
                "kcalLow": meal.kcalLow, "kcalHigh": meal.kcalHigh, "kcalSource": meal.kcalSource.rawValue,
                "proteinG": meal.proteinG, "carbsG": meal.carbsG, "fatG": meal.fatG,
                "healthScore": meal.healthScore, "confidence": meal.confidence.rawValue,
                "provider": meal.provider.rawValue, "modelId": meal.modelId, "userNote": meal.userNote ?? NSNull(),
            ]
        }
        var root: [String: Any] = ["exportedAt": iso.string(from: now), "meals": mealObjects]
        if let profile {
            root["profile"] = [
                "sex": profile.sex.rawValue, "birthDate": iso.string(from: profile.birthDate),
                "heightCm": profile.heightCm, "weightKg": profile.weightKg,
                "activityLevel": profile.activityLevel, "goal": profile.goal.rawValue,
            ]
        }
        return (try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    static func csv(meals: [Meal]) -> Data {
        let header = "date,time,name,kcal,kcal_estimated,kcal_low,kcal_high,protein_g,carbs_g,fat_g,health_score,provider,model,note"
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm"
        let rows = meals.map { meal in
            [
                meal.dayKey, time.string(from: meal.eatenAt), meal.name, "\(meal.kcal)", "\(meal.kcalEstimated)",
                "\(meal.kcalLow)", "\(meal.kcalHigh)", number(meal.proteinG), number(meal.carbsG), number(meal.fatG),
                "\(meal.healthScore)", meal.provider.rawValue, meal.modelId, meal.userNote ?? "",
            ].map(quote).joined(separator: ",")
        }
        let body = ([header] + rows).joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(body.utf8)
    }

    static func write(_ data: Data, name: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try? data.write(to: url, options: .atomic)
        return url
    }

    static func quote(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
