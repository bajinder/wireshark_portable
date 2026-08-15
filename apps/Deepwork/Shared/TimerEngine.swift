// TimerEngine.swift
// Deepwork
//
// The single source of truth for "what is the timer doing". This is a pure
// state machine: it never runs its own `Timer`/ticker, and it never reads
// the wall clock except through the injected `now` closure. Every screen
// (TimerView, the Live Activity, widgets) derives "time remaining" by
// combining this persisted state with the *current* `Date()` at render
// time — never by trusting an in-memory counter that could drift or get
// suspended while the app is backgrounded.
//
// Persistence (see `TimerEngine+Persistence.swift` below) round-trips the
// state through UserDefaults as Codable JSON so a killed-and-relaunched app
// can rehydrate exactly where it left off, then call `refresh()` to fold in
// however much time passed while it was gone.

import Foundation

/// Which interval a Deepwork session is currently in.
enum SessionPhase: String, Codable, Hashable, CaseIterable {
    case focus
    case breakTime

    var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .breakTime: return "Break"
        }
    }
}

/// Persistable description of what the timer is doing right now.
///
/// `startDate`/`endDate` on `.running` are wall-clock `Date`s (not elapsed
/// durations), so `Text(timerInterval:)` and Live Activities can render a
/// live countdown without any app code ticking a clock. `.paused` instead
/// freezes a `remaining` duration, since a paused countdown has no
/// meaningful end date until it resumes.
enum TimerState: Codable, Equatable {
    case idle
    case running(phase: SessionPhase, startDate: Date, endDate: Date)
    case paused(phase: SessionPhase, remaining: TimeInterval)
    /// The running interval's `endDate` has passed. Carries the original
    /// `startDate`/`endDate` so the completed interval can be recorded as
    /// a history `Session` with an accurate duration.
    case finished(phase: SessionPhase, startDate: Date, endDate: Date)
}

/// Pure state machine driving Deepwork's timer.
///
/// Fully unit-testable: every transition is a synchronous, deterministic
/// function of the current `state` and `now()`. No Combine, no async, no
/// side effects — callers (a view model) own persistence and Live Activity
/// updates and call into this type to decide what the *next* state should
/// be.
final class TimerEngine {
    private(set) var state: TimerState
    var focusLength: TimeInterval
    var breakLength: TimeInterval
    let now: () -> Date

    init(
        state: TimerState = .idle,
        focusLength: TimeInterval = 25 * 60,
        breakLength: TimeInterval = 5 * 60,
        now: @escaping () -> Date = Date.init
    ) {
        self.state = state
        self.focusLength = focusLength
        self.breakLength = breakLength
        self.now = now
    }

    // MARK: - Transitions

    /// Begins a fresh countdown for `phase`, overwriting any prior state.
    @discardableResult
    func start(phase: SessionPhase) -> TimerState {
        let start = now()
        let length = phase == .focus ? focusLength : breakLength
        state = .running(phase: phase, startDate: start, endDate: start.addingTimeInterval(length))
        return state
    }

    /// Freezes the remaining time. A no-op (returns the current state
    /// unchanged) unless currently `.running`.
    @discardableResult
    func pause() -> TimerState {
        guard case let .running(phase, _, endDate) = state else { return state }
        let remaining = max(0, endDate.timeIntervalSince(now()))
        state = .paused(phase: phase, remaining: remaining)
        return state
    }

    /// Resumes from a frozen remaining duration, computing a fresh
    /// `endDate` from the current time. A no-op unless currently `.paused`.
    @discardableResult
    func resume() -> TimerState {
        guard case let .paused(phase, remaining) = state else { return state }
        let start = now()
        state = .running(phase: phase, startDate: start, endDate: start.addingTimeInterval(remaining))
        return state
    }

    /// Abandons the current session (no history is recorded for a
    /// cancelled session) and returns to `.idle`.
    @discardableResult
    func cancel() -> TimerState {
        state = .idle
        return state
    }

    /// Folds "time that passed while nobody was ticking anything" into the
    /// state machine. Call this on launch, on foreground, and any time you
    /// need an up-to-date `state` before reading it. If a `.running`
    /// interval's `endDate` has already passed, transitions to `.finished`.
    /// Idempotent and safe to call as often as you like — it never expires
    /// an interval "again" once it's already `.finished`, and it does
    /// nothing at all for `.idle`/`.paused`.
    @discardableResult
    func refresh() -> TimerState {
        if case let .running(phase, startDate, endDate) = state, now() >= endDate {
            state = .finished(phase: phase, startDate: startDate, endDate: endDate)
        }
        return state
    }

    /// Marks a `.finished` session as acknowledged (its history has been
    /// recorded elsewhere) and returns to `.idle`. A no-op unless currently
    /// `.finished`.
    @discardableResult
    func acknowledgeFinished() -> TimerState {
        guard case .finished = state else { return state }
        state = .idle
        return state
    }

    /// Seconds remaining right now. Prefer `Text(timerInterval:)` driven
    /// directly by `state`'s `endDate` for on-screen countdowns — this is
    /// for the rare case (e.g. Live Activity attributes payload) that needs
    /// a plain number instead of a live-updating view.
    var remainingSeconds: TimeInterval {
        switch state {
        case .idle, .finished:
            return 0
        case let .running(_, _, endDate):
            return max(0, endDate.timeIntervalSince(now()))
        case let .paused(_, remaining):
            return remaining
        }
    }
}
