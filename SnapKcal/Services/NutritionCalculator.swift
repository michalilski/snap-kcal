import Foundation

enum NutritionCalculator {
    struct Targets: Equatable, Sendable {
        let bmr: Double
        let tdee: Double
        let lose: Int
        let maintain: Int
        let gain: Int
        let loseRaisedToFloor: Bool

        func value(for goal: Goal) -> Int {
            switch goal {
            case .lose: lose
            case .maintain: maintain
            case .gain: gain
            }
        }
    }

    static let activityMultipliers: [Double] = [1.2, 1.375, 1.55, 1.725]

    static func age(birthDate: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        calendar.dateComponents([.year], from: birthDate, to: now).year ?? 0
    }

    static func bmr(sex: Sex, age: Int, heightCm: Double, weightKg: Double) -> Double {
        10 * weightKg + 6.25 * heightCm - 5 * Double(age) + (sex == .male ? 5 : -161)
    }

    static func tdee(bmr: Double, activityLevel: Int) -> Double {
        bmr * activityMultipliers[min(max(activityLevel, 0), 3)]
    }

    static func roundTo10(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }

    static func targets(sex: Sex, age: Int, heightCm: Double, weightKg: Double, activityLevel: Int) -> Targets {
        let bmr = bmr(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg)
        let tdee = tdee(bmr: bmr, activityLevel: activityLevel)
        let floor = max(sex == .male ? 1500 : 1200, bmr)
        let rawLose = tdee - 500
        return Targets(
            bmr: bmr,
            tdee: tdee,
            lose: roundTo10(max(rawLose, floor)),
            maintain: roundTo10(tdee),
            gain: roundTo10(tdee + 300),
            loseRaisedToFloor: rawLose < floor
        )
    }

    static func target(for profile: UserProfile?, now: Date = .now) -> Int {
        guard let profile else { return 2000 }
        let age = age(birthDate: profile.birthDate, now: now)
        return targets(sex: profile.sex, age: age, heightCm: profile.heightCm, weightKg: profile.weightKg, activityLevel: profile.activityLevel)
            .value(for: profile.goal)
    }
}
