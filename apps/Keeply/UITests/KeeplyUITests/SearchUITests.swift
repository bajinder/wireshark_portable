import XCTest

final class SearchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchFiltersItemListByName() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetData",
            "-uiTestUseSampleImage",
            "-uiTestSampleImageName", "sample_blank"
        ]
        app.launch()

        addManualItem(app: app, name: "Espresso Machine")
        addManualItem(app: app, name: "Cordless Drill")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Drill")

        XCTAssertTrue(app.staticTexts["Cordless Drill"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Espresso Machine"].exists)
    }

    private func addManualItem(app: XCUIApplication, name: String) {
        app.buttons["addItemButton"].tap()

        let nameField = app.textFields["itemNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        nameField.tap()
        nameField.typeText(name)

        app.buttons["saveItemButton"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }
}
