// DeepworkActivityAttributes.swift
// Deepwork
//
// ActivityKit attributes shared verbatim between the app target (which
// starts/updates/ends the Activity) and the ActivityWidget extension
// target (which renders it). This file is compiled into both targets
// independently — there is no binary framework boundary to cross, so plain
// `internal` access is sufficient; keep it that way, since the two targets
// must agree on an *identical* type, not merely a binary-compatible one.

import Foundation
import ActivityKit

struct DeepworkActivityAttributes: ActivityAttributes {
    /// The parts of the countdown that change while the Activity is alive.
    struct ContentState: Codable, Hashable {
        /// Which interval this Activity currently represents.
        var phase: SessionPhase
        /// When the current countdown reaches zero, assuming it is running.
        /// While paused, this is stale for *display* purposes (use
        /// `pausedRemaining` instead) but is still updated to a plausible
        /// future value so a stray render never shows a negative countdown.
        var endDate: Date
        /// Non-nil exactly when paused: the remaining duration frozen at
        /// the moment of pause. `nil` while running.
        var pausedRemaining: TimeInterval?

        var isPaused: Bool { pausedRemaining != nil }
    }

    /// Minutes the focus interval was configured for when this session
    /// started. Static for the Activity's lifetime (ActivityAttributes
    /// itself never changes after `Activity.request`).
    var focusMinutes: Int
    /// Optional free-text tag chosen for this session.
    var tag: String?
}
