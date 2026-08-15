// SettingsView.swift
// Deepwork

import SwiftUI

struct SettingsView: View {
    @Environment(TimerViewModel.self) private var viewModel
    @Environment(EntitlementStore.self) private var entitlementStore

    @State private var showPaywall = false
    @State private var focusMinutes = 25
    @State private var breakMinutes = 5

    private struct Preset: Identifiable, Hashable {
        let focus: Int
        let breakLength: Int
        var id: String { "\(focus)-\(breakLength)" }
    }

    private let freePresets: [Preset] = [
        Preset(focus: 25, breakLength: 5),
        Preset(focus: 50, breakLength: 10),
        Preset(focus: 15, breakLength: 3),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Timer Lengths") {
                    if entitlementStore.isUnlocked {
                        Stepper(value: $focusMinutes, in: 5...120, step: 5) {
                            Text("Focus: \(focusMinutes) min")
                        }
                        .accessibilityIdentifier("settings.focusStepper")
                        .onChange(of: focusMinutes) { _, _ in applyLengths() }

                        Stepper(value: $breakMinutes, in: 1...60, step: 1) {
                            Text("Break: \(breakMinutes) min")
                        }
                        .accessibilityIdentifier("settings.breakStepper")
                        .onChange(of: breakMinutes) { _, _ in applyLengths() }
                    } else {
                        Picker("Preset", selection: presetSelection) {
                            ForEach(freePresets) { preset in
                                Text("\(preset.focus) / \(preset.breakLength) min").tag(preset)
                            }
                        }
                        .accessibilityIdentifier("settings.presetPicker")

                        Button {
                            showPaywall = true
                        } label: {
                            Label("Unlock custom lengths", systemImage: "lock")
                        }
                        .accessibilityIdentifier("settings.unlockCustom")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)

                    if entitlementStore.isUnlocked {
                        Label("Unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Unlock Deepwork") { showPaywall = true }
                            .accessibilityIdentifier("settings.unlockButton")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: syncFromEngine)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var presetSelection: Binding<Preset> {
        Binding(
            get: {
                freePresets.first { $0.focus == focusMinutes && $0.breakLength == breakMinutes } ?? freePresets[0]
            },
            set: { preset in
                focusMinutes = preset.focus
                breakMinutes = preset.breakLength
                applyLengths()
            }
        )
    }

    private func syncFromEngine() {
        focusMinutes = Int(viewModel.engine.focusLength / 60)
        breakMinutes = Int(viewModel.engine.breakLength / 60)
    }

    private func applyLengths() {
        viewModel.configureLengths(focusMinutes: focusMinutes, breakMinutes: breakMinutes)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

#Preview {
    SettingsView()
        .environment(TimerViewModel())
        .environment(EntitlementStore())
}
