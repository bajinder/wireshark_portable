import XCTest

final class PaywallUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddingASixthItemShowsThePaywall() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetData",
            "-uiTestUseSampleImage",
            "-uiTestSampleImageName", "sample_blank"
        ]
        app.launch()

        for index in 1...5 {
            addManualItem(app: app, name: "Item \(index)")
        }

        // A 6th add attempt should be gated behind the paywall instead of
        // opening the add-item form.
        app.buttons["addItemButton"].tap()

        let paywallShown = app.staticTexts["Unlock Unlimited Items"].waitForExistence(timeout: 10)
        XCTAssertTrue(paywallShown)
        XCTAssertFalse(app.textFields["itemNameField"].exists)

        app.buttons["closePaywallButton"].tap()
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
