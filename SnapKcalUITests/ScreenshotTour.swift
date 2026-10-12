import XCTest

/// Captures every main screen to SCREENSHOT_DIR (pass TEST_RUNNER_SCREENSHOT_DIR to xcodebuild). Skipped otherwise.
final class ScreenshotTour: XCTestCase {
    @MainActor
    func testCaptureScreens() throws {
        guard let directory = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { throw XCTSkip("SCREENSHOT_DIR not set") }
        let app = XCUIApplication()
        app.launchArguments = ["-mockAI", "-uiTesting", "-mockPhoto"]
        app.launch()

        func shot(_ name: String) {
            sleep(1)
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
        }

        let next = app.buttons["onboardingNext"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        shot("01-onboarding-body")
        next.tap()
        shot("02-onboarding-activity")
        next.tap()
        shot("03-onboarding-goal")
        next.tap()
        shot("04-onboarding-ai")
        next.tap()

        XCTAssertTrue(app.buttons["snapButton"].waitForExistence(timeout: 10))
        shot("05-today-empty")
        app.buttons["snapButton"].tap()
        shot("06-analyzing")
        XCTAssertTrue(app.staticTexts["resultMealName"].waitForExistence(timeout: 10))
        shot("07-result")
        app.buttons["doneButton"].tap()
        shot("08-today-meal")
        app.descendants(matching: .any)["mealRow"].firstMatch.tap()
        shot("09-meal-detail")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["tab-calendar"].tap()
        shot("10-calendar")
        app.buttons["tab-stats"].tap()
        shot("11-stats")
        app.buttons["tab-setup"].tap()
        shot("12-setup")
        app.swipeUp()
        shot("13-setup-ai")
    }
}
