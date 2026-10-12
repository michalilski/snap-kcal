import Foundation
import Testing
@testable import SnapKcal

struct NutritionCalculatorTests {
    @Test func workedExample() {
        let targets = NutritionCalculator.targets(sex: .male, age: 30, heightCm: 180, weightKg: 80, activityLevel: 1)
        #expect(targets.bmr == 1780)
        #expect(targets.tdee == 2447.5)
        #expect(targets.maintain == 2450)
        #expect(targets.lose == 1950)
        #expect(targets.gain == 2750)
        #expect(!targets.loseRaisedToFloor)
    }

    @Test func femaleSafetyFloor() {
        let targets = NutritionCalculator.targets(sex: .female, age: 60, heightCm: 150, weightKg: 45, activityLevel: 0)
        #expect(targets.lose == 1200)
        #expect(targets.loseRaisedToFloor)
    }

    @Test func maleSafetyFloor() {
        let targets = NutritionCalculator.targets(sex: .male, age: 70, heightCm: 160, weightKg: 55, activityLevel: 0)
        #expect(targets.lose >= 1500)
        #expect(targets.loseRaisedToFloor)
    }

    @Test func loseNeverBelowBMR() {
        let targets = NutritionCalculator.targets(sex: .male, age: 20, heightCm: 200, weightKg: 140, activityLevel: 0)
        #expect(Double(targets.lose) >= targets.bmr - 5)
    }

    @Test func ageOnBirthday() {
        let calendar = TestCalendar.make()
        let birth = TestCalendar.date("1996-10-12", calendar: calendar)
        #expect(NutritionCalculator.age(birthDate: birth, now: TestCalendar.date("2026-10-11 23:59", calendar: calendar), calendar: calendar) == 29)
        #expect(NutritionCalculator.age(birthDate: birth, now: TestCalendar.date("2026-10-12 00:01", calendar: calendar), calendar: calendar) == 30)
    }

    @Test(arguments: [(0, 1.2), (1, 1.375), (2, 1.55), (3, 1.725)])
    func activityMultipliers(level: Int, multiplier: Double) {
        #expect(NutritionCalculator.tdee(bmr: 1000, activityLevel: level) == 1000 * multiplier)
    }

    @Test func roundsToNearestTen() {
        #expect(NutritionCalculator.roundTo10(2447.5) == 2450)
        #expect(NutritionCalculator.roundTo10(1944) == 1940)
    }

    @Test func profileDraftValidation() {
        var draft = ProfileDraft()
        #expect(draft.isValid)
        draft.heightCm = 100
        #expect(!draft.isValid)
    }
}
