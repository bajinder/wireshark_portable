import XCTest

/// Verifies the free-tier gate: the first 3 countdowns/habits (combined) can be created
/// freely, and the 4th attempt shows the paywall instead of the editor.
///
/// This test relies on the app running with the bundled `Countable.storekit`
/// configuration attached to the scheme (see `UITestSupport` and `project.yml`'s
/// `scheme.storeKitConfiguration`) so `Product.products(for:)` resolves the
/// `com.bajinder.countable.unlock` product locally without hitting App Store Connect.
final class PurchaseGateUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPaywallAppearsOnFourthItem() throws {
        let app = UITestSupport.launchApp()

        app.tabBars.buttons["tab.countdowns"].tap()
        UITestSupport.addCountdown(named: "Countdown One", in: app)
        UITestSupport.addCountdown(named: "Countdown Two", in: app)
        UITestSupport.addCountdown(named: "Countdown Three", in: app)

        XCTAssertTrue(app.buttons["countdown.row.Countdown Three"].waitForExistence(timeout: 5))

        // The 4th item (free limit is 3 total) should be blocked by the paywall
        // instead of opening the "New Countdown" editor.
        app.buttons["countdown.addButton"].tap()

        // "paywall.closeButton" is a real toolbar Button (unlike the paywall's root
        // container, which is a plain VStack and not reliably queryable by trait), so
        // it's the sturdiest signal that the paywall sheet — not the countdown editor
        // — is what came up.
        let closeButton = app.buttons["paywall.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Paywall should appear when exceeding the free item limit")

        let titleFieldStillClosed = app.textFields["countdown.titleField"]
        XCTAssertFalse(titleFieldStillClosed.exists, "The countdown editor should not be shown once the free limit is hit")

        closeButton.tap()
    }
}
