// TimerEngine+Persistence.swift
// Deepwork
//
// Codable round-trip of TimerEngine's state through UserDefaults. Every
// transition in the app must call `persist(to:)` immediately afterwards so
// state on disk never lags behind `state` in memory — that's what makes
// "app got killed mid-focus-session" recoverable.

import Foundation

/// The full on-disk snapshot: the state machine plus the lengths it was
/// configured with (lengths matter for rehydration — a `.finished` session
/// only carries its own `startDate`/`endDate`, but a still-`.running`
/// session's `endDate` was already computed from whatever length was
/// active when it started, so persisting lengths here is purely to restore
/// the *next* session's configuration, not to reinterpret this one).
struct PersistedTimer: Codable, Equatable {
    var state: TimerState
    var focusLength: TimeInterval
    var breakLength: TimeInterval
}

extension TimerEngine {
    private static let defaultsKey = "com.bajinder.deepwork.timerState"

    /// Loads the last-persisted snapshot, or `nil` if none exists yet (first
    /// launch) or the stored payload couldn't be decoded (treated the same
    /// as "no state" rather than crashing).
    static func loadPersisted(from defaults: UserDefaults = .standard) -> PersistedTimer? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(PersistedTimer.self, from: data)
    }

    /// Writes the current state and lengths to `defaults`. Silently does
    /// nothing if encoding fails (it never can for this simple Codable
    /// graph, but persistence must never be allowed to crash the timer).
    func persist(to defaults: UserDefaults = .standard) {
        let snapshot = PersistedTimer(state: state, focusLength: focusLength, breakLength: breakLength)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    /// Removes any persisted snapshot. Used by UI test bootstrapping to
    /// guarantee a clean starting state regardless of what a previous test
    /// run left behind on the simulator.
    static func clearPersisted(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: defaultsKey)
    }
}
