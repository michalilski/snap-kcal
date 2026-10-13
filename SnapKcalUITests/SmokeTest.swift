import XCTest

final class SmokeTest: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launchThroughOnboarding() -> XCUIApplication {
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
        XCTAssertTrue(app.buttons["snapButton"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testOnboardingToLoggedMealWithFollowUp() {
        let app = launchThroughOnboarding()
        app.buttons["snapButton"].tap()

        let field = app.textViews["composeField"].exists ? app.textViews["composeField"] : app.textFields["composeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("toast with cheese")
        app.buttons["analyzeButton"].tap()

        let name = app.staticTexts["resultMealName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.label, "Chicken burrito bowl")

        let composer = app.textViews["composerField"].exists ? app.textViews["composerField"] : app.textFields["composerField"]
        composer.tap()
        composer.typeText("there are also 2 slices of ham")
        app.buttons["composerSend"].tap()
        let refined = NSPredicate(format: "label == %@", "Chicken burrito bowl with ham")
        expectation(for: refined, evaluatedWith: name)
        waitForExpectations(timeout: 10)

        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mealRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["dayTotal"].firstMatch.label.contains("720"))
        XCTAssertTrue(app.descendants(matching: .any)["workoutBonus"].firstMatch.waitForExistence(timeout: 5))

        app.buttons["tab-stats"].tap()
        app.buttons["tab-calendar"].tap()
        app.buttons["tab-setup"].tap()
        XCTAssertTrue(app.buttons["testModel"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTextOnlyMeal() {
        let app = launchThroughOnboarding()
        app.buttons["describeButton"].tap()
        let field = app.textViews["composeField"].exists ? app.textViews["composeField"] : app.textFields["composeField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("grahamka z Zabki")
        app.buttons["analyzeButton"].tap()
        XCTAssertTrue(app.staticTexts["resultMealName"].waitForExistence(timeout: 10))
        app.buttons["doneButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["mealRow"].waitForExistence(timeout: 5))
    }
}
