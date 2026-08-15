// TimerViewModel.swift
// Deepwork
//
// Orchestrates TimerEngine + persistence + LiveActivityManager + SwiftData
// history recording. TimerEngine itself stays a pure, side-effect-free
// state machine (see Shared/TimerEngine.swift); this type is where "and
// also tell the Live Activity, and also write history" lives, so the
// engine remains trivially unit-testable on its own.
//
// IMPORTANT — why `timerState` exists as its own stored property:
// `@Observable` only tracks *direct* stored-property writes on the
// `@Observable` type itself. `engine` is a plain (non-Observable)
// reference type, so mutating `engine.state` internally does NOT notify
// SwiftUI that anything changed — the `engine` property's own value (the
// object reference) never changes. Views must therefore read
// `viewModel.timerState`, never `viewModel.engine.state`; every mutator
// below re-mirrors `engine.state` into `timerState` right after touching
// the engine so that read stays truthful and reactive.

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class TimerViewModel {
    private(set) var engine: TimerEngine
    /// Reactive mirror of `engine.state` — see the file-level note above.
    /// Views should always read this, not `engine.state` directly.
    private(set) var timerState: TimerState

    private let liveActivity = LiveActivityManager()
    private let defaults: UserDefaults

    /// Tag typed/selected before starting a focus session. Cleared once the
    /// session starts so the field is empty for the next one.
    var selectedTag: String = ""

    private var modelContext: ModelContext?

    /// Durable copy of "the tag for the session currently in flight",
    /// separate from `selectedTag` (which is in-memory UI state that does
    /// NOT survive an app relaunch). A session that finishes while the app
    /// is backgrounded — or was killed and relaunched entirely — still
    /// needs its tag when it's recorded in `recordFinishedSessionIfNeeded`,
    /// long after `selectedTag` has reset to "" in a fresh `TimerViewModel`.
    private static let pendingTagDefaultsKey = "com.bajinder.deepwork.pendingTag"

    /// `endDate.timeIntervalSince1970` of the most recently recorded
    /// `.finished` interval, so `recordFinishedSessionIfNeeded` — which can
    /// run every time `rehydrate()` fires while state stays `.finished`
    /// awaiting acknowledgement — never inserts the same completed session
    /// into history twice.
    private static let lastRecordedEndDateKey = "com.bajinder.deepwork.lastRecordedEndDate"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        let engine: TimerEngine
        if arguments.contains("-uiTestShortTimer") {
            // Deterministic, fast-finishing timer for UI tests: 5 seconds
            // instead of the real 25/5 minute defaults, and no leftover
            // state from a previous run.
            TimerEngine.clearPersisted(in: defaults)
            engine = TimerEngine(focusLength: 5, breakLength: 5)
        } else if let persisted = TimerEngine.loadPersisted(from: defaults) {
            engine = TimerEngine(
                state: persisted.state,
                focusLength: persisted.focusLength,
                breakLength: persisted.breakLength
            )
        } else {
            engine = TimerEngine()
        }
        self.engine = engine
        self.timerState = engine.state
    }

    /// Wires up the SwiftData context used to record completed sessions.
    /// Call once, as soon as the app's ModelContainer is available.
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Call on launch, on every foreground transition, and periodically
    /// while a session screen is visible (see `TimerView`'s polling
    /// `.task`). Folds in however much time passed since the last check,
    /// records history for any session that finished, and re-syncs the
    /// Live Activity. Idempotent and safe to call as often as needed —
    /// this is what makes backgrounding/relaunch-mid-session recoverable.
    func rehydrate() {
        engine.refresh()
        recordFinishedSessionIfNeeded()
        persist()
        syncLiveActivity()
        syncState()
    }

    /// Only takes effect for the *next* session started — never mutates a
    /// currently running/paused countdown's already-computed end date.
    func configureLengths(focusMinutes: Int, breakMinutes: Int) {
        engine.focusLength = TimeInterval(max(1, focusMinutes) * 60)
        engine.breakLength = TimeInterval(max(1, breakMinutes) * 60)
        persist()
    }

    func start(phase: SessionPhase) {
        let trimmedTag = selectedTag.trimmingCharacters(in: .whitespaces)
        let tag = (phase == .focus && !trimmedTag.isEmpty) ? trimmedTag : nil
        setPendingTag(tag)

        engine.start(phase: phase)
        persist()
        syncState()

        guard case let .running(_, _, endDate) = engine.state else { return }
        liveActivity.start(
            phase: phase,
            endDate: endDate,
            focusMinutes: Int(engine.focusLength / 60),
            tag: tag
        )
        if phase == .focus {
            selectedTag = ""
        }
    }

    func pause() {
        engine.pause()
        persist()
        syncLiveActivity()
        syncState()
    }

    func resume() {
        engine.resume()
        persist()
        syncLiveActivity()
        syncState()
    }

    func cancel() {
        engine.cancel()
        persist()
        setPendingTag(nil)
        liveActivity.end(dismissalPolicy: .immediate)
        syncState()
    }

    /// Acknowledges the just-finished session and immediately starts the
    /// complementary phase (focus -> break, break -> focus).
    func acknowledgeFinishedAndStartNext() {
        guard case let .finished(phase, _, _) = engine.state else { return }
        engine.acknowledgeFinished()
        let next: SessionPhase = phase == .focus ? .breakTime : .focus
        start(phase: next) // persists + syncs state/Live Activity itself
    }

    /// Acknowledges the just-finished session without starting another one.
    func dismissFinished() {
        engine.acknowledgeFinished()
        persist()
        liveActivity.end()
        syncState()
    }

    // MARK: - Private

    private func recordFinishedSessionIfNeeded() {
        guard case let .finished(phase, startDate, endDate) = engine.state, let modelContext else { return }

        let endDateStamp = endDate.timeIntervalSince1970
        guard defaults.double(forKey: Self.lastRecordedEndDateKey) != endDateStamp else {
            return // already recorded this exact finished interval
        }

        let tag = phase == .focus ? pendingTag() : nil
        let session = Session(phase: phase, startDate: startDate, endDate: endDate, tag: tag)
        modelContext.insert(session)
        // Save explicitly rather than waiting on SwiftData's autosave timing —
        // this makes the record durable immediately (the app could be
        // killed moments later) and lets `HistoryView`'s `@Query` pick it
        // up right away instead of on whatever schedule autosave uses.
        try? modelContext.save()
        setPendingTag(nil)
        defaults.set(endDateStamp, forKey: Self.lastRecordedEndDateKey)
    }

    private func persist() {
        engine.persist(to: defaults)
    }

    private func syncState() {
        timerState = engine.state
    }

    private func pendingTag() -> String? {
        defaults.string(forKey: Self.pendingTagDefaultsKey)
    }

    private func setPendingTag(_ tag: String?) {
        if let tag {
            defaults.set(tag, forKey: Self.pendingTagDefaultsKey)
        } else {
            defaults.removeObject(forKey: Self.pendingTagDefaultsKey)
        }
    }

    private func syncLiveActivity() {
        switch engine.state {
        case let .running(phase, _, endDate):
            Task { await liveActivity.update(phase: phase, endDate: endDate, pausedRemaining: nil) }
        case let .paused(phase, remaining):
            let projectedEnd = Date().addingTimeInterval(remaining)
            Task { await liveActivity.update(phase: phase, endDate: projectedEnd, pausedRemaining: remaining) }
        case .idle, .finished:
            liveActivity.end()
        }
    }
}
