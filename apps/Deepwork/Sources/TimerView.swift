// TimerView.swift
// Deepwork

import SwiftUI

struct TimerView: View {
    @Environment(TimerViewModel.self) private var viewModel

    private let suggestedTags = ["Writing", "Code", "Reading", "Design", "Study"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                phaseLabel

                countdown
                    .accessibilityIdentifier("timer.countdown")

                if case .idle = viewModel.timerState {
                    tagField(viewModel: viewModel)
                        .padding(.horizontal)
                }

                controls

                Spacer()
                Spacer()
            }
            .padding()
            .navigationTitle("Deepwork")
            .alert(alertTitle, isPresented: isShowingFinishedAlert) {
                Button(primaryButtonTitle) { viewModel.acknowledgeFinishedAndStartNext() }
                Button("Not now", role: .cancel) { viewModel.dismissFinished() }
            } message: {
                Text(alertMessage)
            }
            // Text(timerInterval:) keeps the on-screen number live on its
            // own, but the state machine itself only advances when
            // something calls `rehydrate()`. This loop is a convenience so
            // the "session finished" alert appears promptly even if the
            // app never leaves the foreground; it is NOT the correctness
            // mechanism — launch/foreground rehydration already guarantees
            // a session that finished while backgrounded is recorded and
            // reflected correctly without this loop ever running.
            .task {
                while !Task.isCancelled {
                    viewModel.rehydrate()
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    // MARK: - Subviews

    private var phaseLabel: some View {
        Text(currentPhaseDisplayName)
            .font(.headline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("timer.phaseLabel")
    }

    @ViewBuilder
    private var countdown: some View {
        Group {
            switch viewModel.timerState {
            case .idle:
                Text(format(viewModel.engine.focusLength))
            case let .running(_, startDate, endDate):
                Text(timerInterval: startDate...endDate, countsDown: true)
            case let .paused(_, remaining):
                Text(format(remaining))
            case .finished:
                Text(format(0))
            }
        }
        .font(.system(size: 64, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }

    private func tagField(viewModel: TimerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tag (optional)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("e.g. Writing", text: Binding(
                get: { viewModel.selectedTag },
                set: { viewModel.selectedTag = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .accessibilityIdentifier("timer.tagField")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestedTags, id: \.self) { tag in
                        Button(tag) { viewModel.selectedTag = tag }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("timer.tagSuggestion.\(tag)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.timerState {
        case .idle:
            Button("Start Focus") { viewModel.start(phase: .focus) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("timer.startFocus")

        case .running:
            HStack(spacing: 16) {
                Button("Pause") { viewModel.pause() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("timer.pause")

                Button("Cancel", role: .destructive) { viewModel.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("timer.cancel")
            }

        case .paused:
            HStack(spacing: 16) {
                Button("Resume") { viewModel.resume() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("timer.resume")

                Button("Cancel", role: .destructive) { viewModel.cancel() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("timer.cancel")
            }

        case .finished:
            EmptyView()
        }
    }

    // MARK: - Derived display state

    private var currentPhaseDisplayName: String {
        switch viewModel.timerState {
        case .idle: return "Ready to focus"
        case let .running(phase, _, _): return phase == .focus ? "Focusing" : "On a break"
        case let .paused(phase, _): return phase == .focus ? "Focus paused" : "Break paused"
        case let .finished(phase, _, _): return phase == .focus ? "Focus complete" : "Break complete"
        }
    }

    private var finishedPhase: SessionPhase? {
        if case let .finished(phase, _, _) = viewModel.timerState { return phase }
        return nil
    }

    private var isShowingFinishedAlert: Binding<Bool> {
        Binding(
            get: {
                if case .finished = viewModel.timerState { return true }
                return false
            },
            set: { newValue in
                // SwiftUI flips `isPresented` to false after ANY alert
                // button fires — including our own primary action, which
                // may have already advanced past `.finished` into a fresh
                // `.running` state (and started its Live Activity). Only
                // treat this as "user dismissed without acting" if we're
                // still actually sitting in `.finished`; otherwise this
                // would immediately end the Live Activity we just started.
                if !newValue, case .finished = viewModel.timerState {
                    viewModel.dismissFinished()
                }
            }
        )
    }

    private var alertTitle: String {
        finishedPhase == .focus ? "Nice focus session!" : "Break's over"
    }

    private var alertMessage: String {
        finishedPhase == .focus ? "Want to take a short break?" : "Ready to start another focus session?"
    }

    private var primaryButtonTitle: String {
        finishedPhase == .focus ? "Start break" : "Start focusing"
    }

    private func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    TimerView()
        .environment(TimerViewModel())
}
