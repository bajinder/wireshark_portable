//
//  CatchbookUITests.swift
//  CatchbookUITests
//
//  Drives the compiled app via accessibility identifiers only. Every
//  scenario launches with `-uiTestInMemoryStore` so runs never touch or
//  pollute a real on-device SwiftData store, and location behavior is
//  controlled deterministically via `-uiTestMockLocation allow|deny`.
//

import XCTest

final class CatchbookUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func makeApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestInMemoryStore"] + extraArguments
        return app
    }

    private func logCatch(in app: XCUIApplication, species: String) {
        app.tabBars.buttons["tab.log"].tap()

        let speciesField = app.textFields["field.species"]
        XCTAssertTrue(speciesField.waitForExistence(timeout: 5))
        speciesField.tap()
        speciesField.typeText(species)
    }

    // MARK: - Location denied never blocks saving

    func testLogCatchWithLocationDeniedSavesWithoutBlocking() {
        let app = makeApp(extraArguments: ["-uiTestMockLocation", "deny"])
        app.launch()

        logCatch(in: app, species: "Smallmouth Bass")

        let locationToggle = app.switches["toggle.addLocation"]
        XCTAssertTrue(locationToggle.exists)
        locationToggle.tap()

        let unavailableLabel = app.staticTexts["label.locationUnavailable"]
        XCTAssertTrue(unavailableLabel.waitForExistence(timeout: 5), "Denied location should show an inline note, not block the form.")

        let saveButton = app.buttons["button.saveCatch"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.alerts["Catch Saved"].waitForExistence(timeout: 5))
        app.alerts["Catch Saved"].buttons["OK"].tap()
    }

    // MARK: - Location allowed captures a coordinate

    func testLogCatchWithLocationAllowedCapturesCoordinate() {
        let app = makeApp(extraArguments: ["-uiTestMockLocation", "allow"])
        app.launch()

        logCatch(in: app, species: "Rainbow Trout")

        let locationToggle = app.switches["toggle.addLocation"]
        XCTAssertTrue(locationToggle.exists)
        locationToggle.tap()

        let capturedLabel = app.staticTexts["label.locationCaptured"]
        XCTAssertTrue(capturedLabel.waitForExistence(timeout: 5))

        let unavailableLabel = app.staticTexts["label.locationUnavailable"]
        XCTAssertFalse(unavailableLabel.exists)

        let saveButton = app.buttons["button.saveCatch"]
        saveButton.tap()

        XCTAssertTrue(app.alerts["Catch Saved"].waitForExistence(timeout: 5))
        app.alerts["Catch Saved"].buttons["OK"].tap()
    }

    // MARK: - Species filter

    func testSpeciesFilterInCatchList() {
        let app = makeApp()
        app.launch()

        logCatch(in: app, species: "Pike")
        let saveButton = app.buttons["button.saveCatch"]
        saveButton.tap()
        XCTAssertTrue(app.alerts["Catch Saved"].waitForExistence(timeout: 5))
        app.alerts["Catch Saved"].buttons["OK"].tap()

        app.tabBars.buttons["tab.list"].tap()
        XCTAssertTrue(app.otherElements["catchListView"].waitForExistence(timeout: 5))

        app.buttons["speciesFilterMenu"].tap()
        let pikeOption = app.buttons["speciesFilter.Pike"]
        XCTAssertTrue(pikeOption.waitForExistence(timeout: 5))
        pikeOption.tap()

        XCTAssertTrue(app.staticTexts["Pike"].waitForExistence(timeout: 5))
    }

    // MARK: - Purchase gate on the 11th catch

    func testPurchaseGateShowsOnEleventhCatch() {
        let app = makeApp(extraArguments: ["-uiTestPreseedCatches", "10"])
        app.launch()

        logCatch(in: app, species: "Walleye")

        let saveButton = app.buttons["button.saveCatch"]
        saveButton.tap()

        XCTAssertTrue(app.otherElements["paywallView"].waitForExistence(timeout: 5), "An 11th catch without the unlock should show the paywall.")
        XCTAssertTrue(app.buttons["button.dismissPaywall"].exists)

        app.buttons["button.dismissPaywall"].tap()
    }
}
