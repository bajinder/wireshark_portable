// HistoryView.swift
// Deepwork

import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Environment(EntitlementStore.self) private var entitlementStore
    @Query(sort: \Session.startDate, order: .reverse) private var sessions: [Session]

    @State private var showPaywall = false

    private let calendar = Calendar.current

    private var aggregator: HistoryAggregator { HistoryAggregator(calendar: calendar) }

    private var focusRecords: [FocusRecord] {
        sessions
            .filter { $0.sessionPhase == .focus }
            .map { FocusRecord(start: $0.startDate, minutes: $0.durationMinutes) }
    }

    private var last7Days: [HistoryAggregator.DayTotal] {
        aggregator.dailyFocusMinutes(records: focusRecords, referenceDate: Date(), dayCount: 7)
    }

    /// Free tier only shows the last 7 days of session history; the unlock
    /// removes this cutoff.
    private var visibleSessions: [Session] {
        guard !entitlementStore.isUnlocked else { return sessions }
        guard let cutoff = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date())) else {
            return sessions
        }
        return sessions.filter { $0.startDate >= cutoff }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Last 7 Days") {
                    chart
                        .frame(height: 200)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("history.chart")
                        .listRowInsets(EdgeInsets())
                        .padding(.horizontal)
                }

                if !entitlementStore.isUnlocked {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Unlock full history & custom timers", systemImage: "lock.open")
                        }
                        .accessibilityIdentifier("history.unlockPrompt")
                    }
                }

                Section("Sessions") {
                    if visibleSessions.isEmpty {
                        Text("No sessions yet. Start a focus session to see it here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(visibleSessions) { session in
                            SessionRow(session: session)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var chart: some View {
        Chart(last7Days) { day in
            BarMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Minutes", day.minutes)
            )
            .foregroundStyle(.blue)
        }
    }
}

private struct SessionRow: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionPhase == .focus ? "Focus" : "Break")
                    .font(.subheadline.weight(.medium))
                if let tag = session.tag, !tag.isEmpty {
                    Text(tag)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.durationMinutes.rounded())) min")
                    .font(.subheadline)
                Text(session.startDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("history.session.\(session.id.uuidString)")
    }
}

#Preview {
    HistoryView()
        .environment(EntitlementStore())
        .modelContainer(for: Session.self, inMemory: true)
}
