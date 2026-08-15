// DeepworkUITests.swift
// DeepworkUITests
//
// Runs against a real installed app instance (device or simulator), driven
// entirely through accessibility identifiers. `-uiTestShortTimer` (read by
// TimerViewModel) shortens the focus/break length to 5 seconds so
// "finished" flows are testable without a multi-minute wait.

import XCTest

final class DeepworkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launchWithShortTimer() {
        app.launchArguments = ["-uiTestShortTimer"]
        app.launch()
    }

    func testStartPauseResumeAndCancelFlow() {
        launchWithShortTimer()

        let startButton = app.buttons["timer.startFocus"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let pauseButton = app.buttons["timer.pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        pauseButton.tap()

        let resumeButton = app.buttons["timer.resume"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()

        let cancelButton = app.buttons["timer.cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        // Cancelling returns straight to the idle "Start Focus" screen.
        XCTAssertTrue(app.buttons["timer.startFocus"].waitForExistence(timeout: 5))
    }

    func testFocusSessionFinishesAndOffersABreak() {
        launchWithShortTimer()

        let startButton = app.buttons["timer.startFocus"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        // The short-timer launch argument makes the focus interval 5
        // seconds long, so the finished alert should appear well within
        // this timeout even accounting for the 1s foreground poll loop.
        let finishedAlert = app.alerts.firstMatch
        XCTAssertTrue(finishedAlert.waitForExistence(timeout: 10))

        // Dismiss via whichever button is last (our alert's "Not now"
        // cancel action) so the flow ends back at idle regardless of exact
        // button ordering.
        let lastButtonIndex = finishedAlert.buttons.count - 1
        XCTAssertGreaterThanOrEqual(lastButtonIndex, 0)
        finishedAlert.buttons.element(boundBy: lastButtonIndex).tap()

        XCTAssertTrue(app.buttons["timer.startFocus"].waitForExistence(timeout: 5))
    }

    func testEnteringATagBeforeStartingAFocusSession() {
        launchWithShortTimer()

        let tagField = app.textFields["timer.tagField"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 5))
        tagField.tap()
        tagField.typeText("Writing")

        let suggestion = app.buttons["timer.tagSuggestion.Code"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()

        XCTAssertEqual(tagField.value as? String, "Code")

        let startButton = app.buttons["timer.startFocus"]
        XCTAssertTrue(startButton.exists)
        startButton.tap()

        // Once running, the tag field is no longer shown (only visible
        // while idle).
        XCTAssertFalse(app.textFields["timer.tagField"].exists)
    }

    func testCustomTimerLengthIsGatedBehindThePaywall() {
        app.launch()

        let settingsTab = app.tabBars.buttons["tab.settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        // Free tier: no purchase has been made, so the preset picker +
        // unlock prompt are shown instead of the custom-length steppers.
        let unlockButton = app.buttons["settings.unlockCustom"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 5))
        XCTAssertFalse(app.steppers["settings.focusStepper"].exists)
        unlockButton.tap()

        let purchaseButton = app.buttons["paywall.purchase"]
        XCTAssertTrue(purchaseButton.waitForExistence(timeout: 5))

        let closeButton = app.buttons["paywall.close"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()

        // Closing the paywall without purchasing returns to Settings, still gated.
        XCTAssertTrue(app.buttons["settings.unlockCustom"].waitForExistence(timeout: 5))
    }
}
