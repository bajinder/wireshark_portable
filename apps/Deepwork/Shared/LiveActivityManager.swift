// LiveActivityManager.swift
// Deepwork
//
// Thin wrapper around ActivityKit that mirrors TimerEngine's state onto the
// lock screen / Dynamic Island. This type owns no ticking logic of its
// own — the caller (TimerViewModel) tells it exactly what to show after
// every TimerEngine transition. Starting/updating/ending a Live Activity
// is treated as best-effort UI: any ActivityKit failure (Live Activities
// disabled in Settings, no Activity currently running, etc.) is swallowed
// rather than surfaced, since the timer itself must keep working perfectly
// even if the lock-screen mirror can't.

import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    private var activity: Activity<DeepworkActivityAttributes>?

    /// Whether the system will currently allow a new Live Activity to be
    /// requested (the user may have disabled Live Activities in Settings,
    /// independent of OS/device support).
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts a new Live Activity for the given phase/end date, ending any
    /// previous one first (Deepwork only ever shows one session at a time).
    func start(phase: SessionPhase, endDate: Date, focusMinutes: Int, tag: String?) {
        guard areActivitiesEnabled else { return }
        end(dismissalPolicy: .immediate)

        let attributes = DeepworkActivityAttributes(focusMinutes: focusMinutes, tag: tag)
        let state = DeepworkActivityAttributes.ContentState(phase: phase, endDate: endDate, pausedRemaining: nil)
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))

        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            activity = nil
        }
    }

    /// Pushes an updated content state to the currently running Activity,
    /// if any. Called after pause/resume so the lock screen reflects the
    /// paused flag and a correct countdown immediately.
    func update(phase: SessionPhase, endDate: Date, pausedRemaining: TimeInterval?) async {
        guard let activity else { return }
        let state = DeepworkActivityAttributes.ContentState(phase: phase, endDate: endDate, pausedRemaining: pausedRemaining)
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))
        await activity.update(content)
    }

    /// Ends the currently running Activity, if any.
    func end(dismissalPolicy: ActivityUIDismissalPolicy = .default) {
        guard let activity else { return }
        self.activity = nil
        let finalState = activity.content.state
        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: dismissalPolicy)
        }
    }
}
