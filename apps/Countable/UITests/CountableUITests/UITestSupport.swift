import XCTest

/// Shared helpers for the Countable UI test suite.
///
/// Every test launches the app with the `-uiTesting` argument, which
/// `CountableApp.init()` reads to force a fresh, in-memory SwiftData store instead of
/// the real App Group-backed one (see Sources/CountableApp.swift). This makes every
/// test run start from a clean slate with no leftover data between runs, without
/// needing a simulator reset.
///
/// To exercise the StoreKit purchase flow locally (e.g. `PurchaseGateUITests`), run
/// this scheme with the bundled `Countable.storekit` configuration attached — this is
/// already wired up in `project.yml` (`scheme.storeKitConfiguration`). If Xcode ever
/// loses that association, re-select it via Product > Scheme > Edit Scheme > Run >
/// Options > StoreKit Configuration before running UI tests that touch the paywall.
enum UITestSupport {
    static func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    /// Fills out and saves the "New Countdown" form with the given title, then waits
    /// for the sheet to dismiss.
    static func addCountdown(named title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let addButton = app.buttons["countdown.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Countdown add button not found", file: file, line: line)
        addButton.tap()

        let titleField = app.textFields["countdown.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Countdown title field not found", file: file, line: line)
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons["countdown.saveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save button unexpectedly disabled", file: file, line: line)
        saveButton.tap()
    }

    /// Fills out and saves the "New Habit" form with the given title, then waits for
    /// the sheet to dismiss.
    static func addHabit(named title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let addButton = app.buttons["habit.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Habit add button not found", file: file, line: line)
        addButton.tap()

        let titleField = app.textFields["habit.titleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Habit title field not found", file: file, line: line)
        titleField.tap()
        titleField.typeText(title)

        let saveButton = app.buttons["habit.saveButton"]
        XCTAssertTrue(saveButton.isEnabled, "Save button unexpectedly disabled", file: file, line: line)
        saveButton.tap()
    }
}
