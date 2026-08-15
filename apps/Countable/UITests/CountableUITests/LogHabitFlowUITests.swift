import XCTest

final class LogHabitFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLoggingAHabitTodayUpdatesTheStreak() throws {
        let app = UITestSupport.launchApp()

        app.tabBars.buttons["tab.habits"].tap()
        UITestSupport.addHabit(named: "Meditate", in: app)

        // habit.streakLabel.Meditate only exists once the row itself has rendered, so
        // waiting on it also confirms the row appeared in the list.
        let streakLabel = app.staticTexts["habit.streakLabel.Meditate"]
        XCTAssertTrue(streakLabel.waitForExistence(timeout: 5))
        // Streak starts at 0 days before any log today.
        XCTAssertEqual(streakLabel.label, "0 day streak")

        let logButton = app.buttons["habit.logButton.Meditate"]
        XCTAssertTrue(logButton.waitForExistence(timeout: 5))
        logButton.tap()

        // After logging today, the streak should read as 1 day.
        let updatedStreakLabel = app.staticTexts["habit.streakLabel.Meditate"]
        XCTAssertTrue(updatedStreakLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(updatedStreakLabel.label, "1 day streak")
    }
}
