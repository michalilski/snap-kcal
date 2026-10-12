import XCTest

final class SmokeTest: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingToLoggedMeal() {
        let app = XCUIApplication()
        app.launchArguments = ["-mockAI", "-uiTesting", "-mockPhoto"]
        app.launch()

        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        app.buttons["activity-2"].tap()
        next.tap()
        app.buttons["goal-lose"].tap()
        next.tap()
        next.tap()

        let snap = app.buttons["snapButton"]
        XCTAssertTrue(snap.waitForExistence(timeout: 10))
        snap.tap()

        XCTAssertTrue(app.staticTexts["resultMealName"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["resultMealName"].label, "Chicken burrito bowl")
        app.buttons["doneButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["mealRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["dayTotal"].firstMatch.label.contains("600"))

        app.buttons["tab-stats"].tap()
        app.buttons["tab-calendar"].tap()
        app.buttons["tab-setup"].tap()
        XCTAssertTrue(app.buttons["testModel"].waitForExistence(timeout: 5))
    }
}
