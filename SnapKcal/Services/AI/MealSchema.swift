import Foundation

enum MealSchema {
    static var schema: [String: Any] {
        let item: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "portion", "kcal"],
            "properties": [
                "name": ["type": "string"],
                "portion": ["type": "string", "description": "e.g. '150 g', '1 cup', '2 slices'"],
                "kcal": ["type": "integer"],
            ],
        ]
        return [
            "type": "object",
            "additionalProperties": false,
            "required": [
                "is_food", "meal_name", "description", "items", "kcal_total", "kcal_low", "kcal_high",
                "protein_g", "carbs_g", "fat_g", "health_score", "score_reason", "tip", "confidence",
            ],
            "properties": [
                "is_food": ["type": "boolean"],
                "meal_name": ["type": "string", "description": "Short name, max 40 chars"],
                "description": ["type": "string", "description": "1-2 sentences on what is on the plate"],
                "items": ["type": "array", "items": item],
                "kcal_total": ["type": "integer"],
                "kcal_low": ["type": "integer"],
                "kcal_high": ["type": "integer"],
                "protein_g": ["type": "number"],
                "carbs_g": ["type": "number"],
                "fat_g": ["type": "number"],
                "health_score": ["type": "integer", "description": "1 (poor) to 10 (excellent)"],
                "score_reason": ["type": "string", "description": "Max 80 chars"],
                "tip": ["type": "string", "description": "Max 120 chars"],
                "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
            ],
        ]
    }

    static var jsonString: String {
        let data = (try? JSONSerialization.data(withJSONObject: schema, options: [.sortedKeys])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
