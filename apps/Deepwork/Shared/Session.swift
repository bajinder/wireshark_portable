// Session.swift
// Deepwork
//
// SwiftData model recording one completed focus or break interval.
// Sessions are only ever created for intervals that ran to completion
// (TimerEngine reaching `.finished`) — a cancelled session is intentionally
// never recorded, matching the v1 spec's "cancel" semantics.

import Foundation
import SwiftData

@Model
final class Session {
    var id: UUID
    /// Stored as `SessionPhase.rawValue` since SwiftData's `@Model` macro
    /// works most reliably with primitive stored properties; `sessionPhase`
    /// below provides the typed view.
    var phase: String
    var startDate: Date
    var endDate: Date
    /// Free-text tag the user entered before starting a focus session.
    /// `nil`/empty for untagged sessions and for break intervals.
    var tag: String?

    init(phase: SessionPhase, startDate: Date, endDate: Date, tag: String? = nil, id: UUID = UUID()) {
        self.id = id
        self.phase = phase.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.tag = tag
    }

    var sessionPhase: SessionPhase {
        SessionPhase(rawValue: phase) ?? .focus
    }

    var durationMinutes: Double {
        max(0, endDate.timeIntervalSince(startDate)) / 60
    }
}
