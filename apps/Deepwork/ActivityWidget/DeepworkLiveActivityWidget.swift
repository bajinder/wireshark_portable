// DeepworkLiveActivityWidget.swift
// DeepworkActivity (widget extension)
//
// Renders the Deepwork Live Activity: lock screen banner + Dynamic Island
// (compact and expanded). This file only ever reads `context.state` /
// `context.attributes` — it never runs any timer logic of its own. The
// live-updating countdown text comes entirely from `Text(timerInterval:)`,
// which the system keeps ticking without this process being woken up.

import WidgetKit
import SwiftUI
import ActivityKit

struct DeepworkLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DeepworkActivityAttributes.self) { context in
            DeepworkLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: symbolName(for: context.state.phase))
                        .foregroundStyle(.white)
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownText(state: context.state)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.phase == .focus ? "Focusing" : "On a break")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if context.state.isPaused {
                                Text("Paused")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                            if let tag = context.attributes.tag, !tag.isEmpty {
                                Text(tag)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: symbolName(for: context.state.phase))
            } compactTrailing: {
                countdownText(state: context.state)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 44)
            } minimal: {
                Image(systemName: symbolName(for: context.state.phase))
            }
            .widgetURL(URL(string: "deepwork://timer"))
            .keylineTint(context.state.phase == .focus ? Color.blue : Color.green)
        }
    }
}

private func symbolName(for phase: SessionPhase) -> String {
    phase == .focus ? "brain.head.profile" : "cup.and.saucer.fill"
}

/// Shared countdown rendering used by both the lock screen and the Dynamic
/// Island: a live `Text(timerInterval:)` while running, a frozen duration
/// string while paused (a paused countdown has no meaningful end date).
@ViewBuilder
private func countdownText(state: DeepworkActivityAttributes.ContentState) -> some View {
    let now = Date()
    if state.isPaused, let remaining = state.pausedRemaining {
        Text(staticDuration(remaining))
    } else if state.endDate > now {
        // `ClosedRange` traps if lowerBound > upperBound, and `endDate` can
        // have already passed by the time this renders (the app ends the
        // Activity asynchronously once it notices), so never construct
        // `now...endDate` without checking first.
        Text(timerInterval: now...state.endDate, countsDown: true, showsHours: false)
    } else {
        Text(staticDuration(0))
    }
}

private func staticDuration(_ interval: TimeInterval) -> String {
    let totalSeconds = max(0, Int(interval.rounded()))
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
}

private struct DeepworkLockScreenView: View {
    let attributes: DeepworkActivityAttributes
    let state: DeepworkActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbolName(for: state.phase))
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.phase == .focus ? "Focusing" : "On a break")
                    .font(.headline)
                    .foregroundStyle(.white)
                if let tag = attributes.tag, !tag.isEmpty {
                    Text(tag)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                countdownText(state: state)
                    .font(.system(.title2, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                if state.isPaused {
                    Text("Paused")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
    }
}
