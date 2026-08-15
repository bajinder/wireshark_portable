// TimerEngineTests.swift
// DeepworkTests

import XCTest
@testable import Deepwork

final class TimerEngineTests: XCTestCase {
    private func makeEngine(now: @escaping () -> Date) -> TimerEngine {
        TimerEngine(state: .idle, focusLength: 25 * 60, breakLength: 5 * 60, now: now)
    }

    func testStartSetsRunningStateWithCorrectEndDate() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let engine = makeEngine(now: { start })

        let state = engine.start(phase: .focus)

        guard case let .running(phase, startDate, endDate) = state else {
            return XCTFail("Expected running state, got \(state)")
        }
        XCTAssertEqual(phase, .focus)
        XCTAssertEqual(startDate, start)
        XCTAssertEqual(endDate, start.addingTimeInterval(25 * 60))
    }

    func testPauseAccumulatesRemainingCorrectly() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        current = start.addingTimeInterval(10 * 60) // 10 minutes elapsed
        let state = engine.pause()

        guard case let .paused(phase, remaining) = state else {
            return XCTFail("Expected paused state, got \(state)")
        }
        XCTAssertEqual(phase, .focus)
        XCTAssertEqual(remaining, 15 * 60, accuracy: 0.001)
    }

    func testPausingTwiceLeavesRemainingUnchanged() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        current = start.addingTimeInterval(10 * 60)
        engine.pause()
        current = start.addingTimeInterval(20 * 60) // time keeps passing while paused
        let state = engine.pause() // no-op: already paused

        guard case let .paused(_, remaining) = state else {
            return XCTFail("Expected paused state, got \(state)")
        }
        XCTAssertEqual(remaining, 15 * 60, accuracy: 0.001)
    }

    func testResumeRecomputesEndDateFromNow() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        current = start.addingTimeInterval(10 * 60)
        engine.pause()

        current = start.addingTimeInterval(20 * 60) // resumed 10 minutes after pausing
        let state = engine.resume()

        guard case let .running(phase, startDate, endDate) = state else {
            return XCTFail("Expected running state, got \(state)")
        }
        XCTAssertEqual(phase, .focus)
        XCTAssertEqual(startDate, current)
        XCTAssertEqual(
            endDate.timeIntervalSince1970,
            current.addingTimeInterval(15 * 60).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testCancelReturnsToIdleFromRunning() {
        let engine = makeEngine(now: { Date(timeIntervalSince1970: 0) })
        engine.start(phase: .focus)

        let state = engine.cancel()

        XCTAssertEqual(state, .idle)
    }

    func testCancelReturnsToIdleFromPaused() {
        let start = Date(timeIntervalSince1970: 0)
        var current = start
        let engine = makeEngine(now: { current })
        engine.start(phase: .focus)
        current = start.addingTimeInterval(60)
        engine.pause()

        let state = engine.cancel()

        XCTAssertEqual(state, .idle)
    }

    func testRefreshTransitionsToFinishedWhenEndDatePassedWhileBackgrounded() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        // Simulate the app being backgrounded for far longer than the focus length.
        current = start.addingTimeInterval(60 * 60)

        let state = engine.refresh()

        guard case let .finished(phase, startDate, endDate) = state else {
            return XCTFail("Expected finished state, got \(state)")
        }
        XCTAssertEqual(phase, .focus)
        XCTAssertEqual(startDate, start)
        XCTAssertEqual(endDate, start.addingTimeInterval(25 * 60))
    }

    func testRefreshDoesNothingIfStillRunning() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        current = start.addingTimeInterval(60) // only 1 minute elapsed of 25

        let state = engine.refresh()

        guard case .running = state else {
            return XCTFail("Expected still running, got \(state)")
        }
    }

    func testRefreshIsIdempotentOnceFinished() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        current = start.addingTimeInterval(60 * 60)
        let firstRefresh = engine.refresh()
        current = start.addingTimeInterval(90 * 60) // even more time passes
        let secondRefresh = engine.refresh()

        XCTAssertEqual(firstRefresh, secondRefresh)
    }

    func testRefreshDoesNothingWhileIdleOrPaused() {
        let engine = makeEngine(now: { Date(timeIntervalSince1970: 0) })
        XCTAssertEqual(engine.refresh(), .idle)

        engine.start(phase: .focus)
        engine.pause()
        let pausedState = engine.state
        XCTAssertEqual(engine.refresh(), pausedState)
    }

    func testAcknowledgeFinishedReturnsToIdle() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        var current = start
        let engine = makeEngine(now: { current })

        engine.start(phase: .focus)
        current = start.addingTimeInterval(60 * 60)
        engine.refresh()

        let state = engine.acknowledgeFinished()

        XCTAssertEqual(state, .idle)
    }

    func testAcknowledgeFinishedIsNoOpUnlessFinished() {
        let engine = makeEngine(now: { Date(timeIntervalSince1970: 0) })

        let state = engine.acknowledgeFinished()

        XCTAssertEqual(state, .idle)
    }

    // MARK: - Persistence / rehydration

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "DeepworkTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create an isolated UserDefaults suite for testing")
            return .standard
        }
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testPersistAndLoadRoundTripsState() {
        let defaults = makeIsolatedDefaults()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let engine = makeEngine(now: { start })
        engine.start(phase: .focus)

        engine.persist(to: defaults)
        let persisted = TimerEngine.loadPersisted(from: defaults)

        XCTAssertEqual(persisted?.state, engine.state)
        XCTAssertEqual(persisted?.focusLength, engine.focusLength)
        XCTAssertEqual(persisted?.breakLength, engine.breakLength)
    }

    func testLoadPersistedReturnsNilWhenNothingStored() {
        let defaults = makeIsolatedDefaults()

        XCTAssertNil(TimerEngine.loadPersisted(from: defaults))
    }

    /// Simulates the full "app was killed mid-focus-session and relaunched
    /// much later" flow: persist while running, then construct a BRAND NEW
    /// engine instance (as a fresh app launch would) from the persisted
    /// snapshot with a `now` far in the future, and confirm `refresh()`
    /// correctly reports the session as finished.
    func testRestartAfterRelaunchRehydratesAndFinishesExpiredSession() {
        let defaults = makeIsolatedDefaults()
        let start = Date(timeIntervalSince1970: 1_000_000)

        let beforeRelaunch = makeEngine(now: { start })
        beforeRelaunch.start(phase: .focus)
        beforeRelaunch.persist(to: defaults)

        guard let persisted = TimerEngine.loadPersisted(from: defaults) else {
            return XCTFail("Expected a persisted snapshot to rehydrate from")
        }

        let muchLater = start.addingTimeInterval(60 * 60)
        let afterRelaunch = TimerEngine(
            state: persisted.state,
            focusLength: persisted.focusLength,
            breakLength: persisted.breakLength,
            now: { muchLater }
        )

        let state = afterRelaunch.refresh()

        guard case let .finished(phase, startDate, endDate) = state else {
            return XCTFail("Expected finished state after rehydration, got \(state)")
        }
        XCTAssertEqual(phase, .focus)
        XCTAssertEqual(startDate, start)
        XCTAssertEqual(endDate, start.addingTimeInterval(25 * 60))
    }

    /// Same scenario, but the relaunch happens WHILE the session is still
    /// legitimately running (not enough time has passed) — rehydration
    /// must leave it running, not incorrectly finish it early.
    func testRestartAfterRelaunchWhileStillRunningStaysRunning() {
        let defaults = makeIsolatedDefaults()
        let start = Date(timeIntervalSince1970: 1_000_000)

        let beforeRelaunch = makeEngine(now: { start })
        beforeRelaunch.start(phase: .focus)
        beforeRelaunch.persist(to: defaults)

        guard let persisted = TimerEngine.loadPersisted(from: defaults) else {
            return XCTFail("Expected a persisted snapshot to rehydrate from")
        }

        let shortlyAfter = start.addingTimeInterval(60) // 1 of 25 minutes elapsed
        let afterRelaunch = TimerEngine(
            state: persisted.state,
            focusLength: persisted.focusLength,
            breakLength: persisted.breakLength,
            now: { shortlyAfter }
        )

        let state = afterRelaunch.refresh()

        guard case .running = state else {
            return XCTFail("Expected still running after rehydration, got \(state)")
        }
    }
}
