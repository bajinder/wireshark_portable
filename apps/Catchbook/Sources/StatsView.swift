//
//  StatsView.swift
//  Catchbook
//
//  Summary tiles, biggest-per-species list, and a 12-month bar chart of
//  catches, all driven by the pure StatsCalculator.
//

import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query private var catches: [Catch]

    private var stats: CatchStats {
        StatsCalculator.stats(for: catches, calendar: .current, now: .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 16) {
                        StatTile(title: "Total Catches", value: "\(stats.totalCatches)")
                            .accessibilityIdentifier("stat.totalCatches")
                        StatTile(title: "Species Logged", value: "\(stats.biggestBySpecies.count)")
                            .accessibilityIdentifier("stat.speciesCount")
                    }

                    monthlyChartSection
                    biggestBySpeciesSection
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
        .accessibilityIdentifier("statsView")
    }

    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Catches per Month")
                .font(.headline)

            if stats.monthlyCounts.allSatisfy({ $0.count == 0 }) {
                Text("Log a catch to see your monthly trend.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(stats.monthlyCounts) { item in
                    BarMark(
                        x: .value("Month", item.monthStart, unit: .month),
                        y: .value("Catches", item.count)
                    )
                    .foregroundStyle(.blue)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .frame(height: 200)
                .accessibilityIdentifier("chart.monthlyCatches")
            }
        }
    }

    private var biggestBySpeciesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Biggest by Species")
                .font(.headline)

            if stats.biggestBySpecies.isEmpty {
                Text("No catches logged yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(stats.biggestBySpecies) { entry in
                        HStack {
                            Text(entry.species)
                            Spacer()
                            Text(sizeDescription(for: entry))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                        .accessibilityIdentifier("biggest.\(entry.species)")
                        Divider()
                    }
                }
            }
        }
    }

    private func sizeDescription(for entry: SpeciesBest) -> String {
        if let weight = entry.weight {
            return "\(weight.formatted(.number.precision(.fractionLength(0...2)))) kg"
        } else if let length = entry.length {
            return "\(length.formatted(.number.precision(.fractionLength(0...1)))) cm"
        } else {
            return "—"
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatsView()
        .modelContainer(for: Catch.self, inMemory: true)
}
