import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openai, anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: "OpenAI"
        case .anthropic: "Anthropic"
        }
    }
}

enum MealStatus: String, Codable, Sendable { case analyzing, done, failed }

enum Confidence: String, Codable, Sendable { case low, medium, high }

enum KcalSource: String, Codable, Sendable { case model, portion, manual }

enum Sex: String, Codable, CaseIterable, Sendable { case male, female }

enum Goal: String, Codable, CaseIterable, Sendable { case lose, maintain, gain }

enum AnalysisDetail: String, CaseIterable, Sendable { case fast, accurate }

enum PhotoSource: Equatable, Sendable { case camera, library }

enum DayStatus: Equatable, Sendable {
    case empty, under, onTarget, over, future

    static func of(total: Int?, target: Int) -> DayStatus {
        guard let total, total > 0 else { return .empty }
        let ratio = Double(total) / Double(max(target, 1))
        if ratio < 0.9 { return .under }
        if ratio > 1.1 { return .over }
        return .onTarget
    }
}
