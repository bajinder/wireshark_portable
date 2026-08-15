//
//  LocationProvider.swift
//  Catchbook
//
//  Wraps CLLocationManager behind a small async, protocol-based facade so
//  location is entirely optional: callers get a single best-effort
//  coordinate or nil, never a hard failure. All delegate callbacks are
//  bounced onto the main actor before touching any state.
//

import CoreLocation
import Foundation

/// Abstraction over "get me one current location, or nil". Kept as a
/// protocol so alternate implementations (see `MockLocationProvider`) can
/// be swapped in for testing without touching CLLocationManager.
@MainActor
protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestCurrentLocation() async -> CLLocationCoordinate2D?
}

@MainActor
final class LocationProvider: NSObject, ObservableObject, LocationProviding {

    /// `.live` talks to CLLocationManager. The `.mock*` cases exist so the
    /// compiled app itself can behave deterministically under UI test
    /// automation, which can only influence a black-box binary via launch
    /// arguments (Swift objects can't be injected into another process).
    enum Mode: Equatable {
        case live
        case mockAllow(CLLocationCoordinate2D)
        case mockDeny

        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.live, .live), (.mockDeny, .mockDeny):
                return true
            case let (.mockAllow(a), .mockAllow(b)):
                return a.latitude == b.latitude && a.longitude == b.longitude
            default:
                return false
            }
        }
    }

    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let mode: Mode
    private let manager: CLLocationManager?

    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?
    private var hasResumedLocation = false

    init(mode: Mode = LocationProvider.modeFromLaunchArguments()) {
        self.mode = mode
        switch mode {
        case .live:
            let liveManager = CLLocationManager()
            self.manager = liveManager
            self.authorizationStatus = liveManager.authorizationStatus
        case .mockAllow:
            self.manager = nil
            self.authorizationStatus = .authorizedWhenInUse
        case .mockDeny:
            self.manager = nil
            self.authorizationStatus = .denied
        }
        super.init()
        manager?.delegate = self
    }

    /// Reads `-uiTestMockLocation allow|deny` from the process launch
    /// arguments. Absent (or unrecognized), the app behaves live.
    nonisolated static func modeFromLaunchArguments() -> Mode {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-uiTestMockLocation"),
              flagIndex + 1 < arguments.count else {
            return .live
        }
        switch arguments[flagIndex + 1] {
        case "allow":
            return .mockAllow(CLLocationCoordinate2D(latitude: 45.4215, longitude: -75.6972))
        case "deny":
            return .mockDeny
        default:
            return .live
        }
    }

    /// One-shot request for the current location. Never throws; a denied,
    /// restricted, not-yet-determined-and-refused, or failed request all
    /// simply resolve to nil so callers can treat location as always optional.
    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        switch mode {
        case .mockAllow(let coordinate):
            return coordinate
        case .mockDeny:
            return nil
        case .live:
            return await requestLiveLocation()
        }
    }

    private func requestLiveLocation() async -> CLLocationCoordinate2D? {
        guard let manager else { return nil }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                authorizationContinuation = continuation
            }
            guard granted else { return nil }
        case .denied, .restricted:
            return nil
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            return nil
        }

        hasResumedLocation = false
        return await withCheckedContinuation { (continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>) in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }
}

extension LocationProvider: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            guard let continuation = self.authorizationContinuation else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.authorizationContinuation = nil
                continuation.resume(returning: true)
            case .denied, .restricted:
                self.authorizationContinuation = nil
                continuation.resume(returning: false)
            case .notDetermined:
                break
            @unknown default:
                self.authorizationContinuation = nil
                continuation.resume(returning: false)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            guard !self.hasResumedLocation else { return }
            self.hasResumedLocation = true
            self.locationContinuation?.resume(returning: coordinate)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard !self.hasResumedLocation else { return }
            self.hasResumedLocation = true
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }
}

/// Deterministic stand-in for `LocationProvider`, usable directly in unit
/// tests without touching CLLocationManager or process launch arguments.
@MainActor
final class MockLocationProvider: ObservableObject, LocationProviding {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    private let result: CLLocationCoordinate2D?

    init(authorizationStatus: CLAuthorizationStatus, result: CLLocationCoordinate2D?) {
        self.authorizationStatus = authorizationStatus
        self.result = result
    }

    func requestCurrentLocation() async -> CLLocationCoordinate2D? {
        result
    }
}
