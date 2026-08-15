import XCTest

/// Exercises the add-item flow deterministically by bypassing the real
/// PhotosPicker/camera UI (which XCUITest cannot script reliably across
/// devices/simulators) via the `-uiTestUseSampleImage` launch argument. See
/// README.md / SHIP.md for how this fits into the wider add-item flow.
final class AddItemUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddItemFromSampleReceiptReachesPrefilledForm() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetData",
            "-uiTestUseSampleImage",
            "-uiTestSampleImageName", "sample_receipt_1"
        ]
        app.launch()

        app.buttons["addItemButton"].tap()

        // The sample image bypass skips straight past source-picking into
        // OCR, then the form. Give OCR a generous timeout on slower CI.
        let nameField = app.textFields["itemNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 15))
        XCTAssertTrue(app.images["receiptPreviewImage"].exists)

        nameField.tap()
        nameField.typeText("Wireless Blender")

        let saveButton = app.buttons["saveItemButton"]
        XCTAssertTrue(saveButton.isEnabled)
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Wireless Blender"].waitForExistence(timeout: 5))
    }

    func testOCRFailureOnBlankImageDegradesToManualEntry() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestResetData",
            "-uiTestUseSampleImage",
            "-uiTestSampleImageName", "sample_blank"
        ]
        app.launch()

        app.buttons["addItemButton"].tap()

        let manualNote = app.staticTexts["manualEntryNote"]
        XCTAssertTrue(manualNote.waitForExistence(timeout: 15))

        let nameField = app.textFields["itemNameField"]
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText("Manually Entered Item")

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Manually Entered Item"].waitForExistence(timeout: 5))
    }

    func testManualEntryButtonSkipsPhotoEntirely() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetData"]
        app.launch()

        app.buttons["addItemButton"].tap()
        app.buttons["manualEntryButton"].tap()

        let nameField = app.textFields["itemNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["receiptPreviewImage"].exists)

        nameField.tap()
        nameField.typeText("No Photo Item")
        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["No Photo Item"].waitForExistence(timeout: 5))
    }
}
