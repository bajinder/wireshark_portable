import XCTest

final class AddCountdownFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddingACountdownShowsItInTheList() throws {
        let app = UITestSupport.launchApp()

        app.tabBars.buttons["tab.countdowns"].tap()
        UITestSupport.addCountdown(named: "Trip to Kyoto", in: app)

        let row = app.buttons["countdown.row.Trip to Kyoto"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Newly added countdown should appear in the list")
    }

    func testEmptyTitleCannotBeSaved() throws {
        let app = UITestSupport.launchApp()

        app.tabBars.buttons["tab.countdowns"].tap()
        app.buttons["countdown.addButton"].tap()

        let saveButton = app.buttons["countdown.saveButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        XCTAssertFalse(saveButton.isEnabled, "Save should stay disabled until a title is entered")

        app.buttons["countdown.cancelButton"].tap()
    }
}
