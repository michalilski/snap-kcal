import Foundation
import SwiftData

@Model
final class UserProfile {
    var sex: Sex
    var birthDate: Date
    var heightCm: Double
    var weightKg: Double
    var activityLevel: Int
    var goal: Goal
    var updatedAt: Date

    init(draft: ProfileDraft) {
        sex = draft.sex
        birthDate = draft.birthDate
        heightCm = draft.heightCm
        weightKg = draft.weightKg
        activityLevel = draft.activityLevel
        goal = draft.goal
        updatedAt = .now
    }

    var draft: ProfileDraft {
        ProfileDraft(sex: sex, birthDate: birthDate, heightCm: heightCm, weightKg: weightKg, activityLevel: activityLevel, goal: goal)
    }

    func update(from draft: ProfileDraft) {
        sex = draft.sex
        birthDate = draft.birthDate
        heightCm = draft.heightCm
        weightKg = draft.weightKg
        activityLevel = draft.activityLevel
        goal = draft.goal
        updatedAt = .now
    }
}

struct ProfileDraft: Equatable, Sendable {
    var sex: Sex = .male
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var heightCm: Double = 175
    var weightKg: Double = 75
    var activityLevel: Int = 1
    var goal: Goal = .maintain

    var age: Int { NutritionCalculator.age(birthDate: birthDate, now: .now) }

    var isValid: Bool {
        (120...250).contains(heightCm) && (30...300).contains(weightKg) && (13...100).contains(age)
    }

    var targets: NutritionCalculator.Targets {
        NutritionCalculator.targets(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg, activityLevel: activityLevel)
    }
}
