# Catchbook

A simple fishing catch log for iOS. Log a catch (species, length, weight,
photo, optional location, notes), browse your catches, see them on a map,
and check stats. Log more than 10 catches with a one-time unlock.

## Requirements

- Xcode 15 or later
- iOS 17.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

This project has no `.xcodeproj` checked in — it's generated from
`project.yml`.

## Getting started

```sh
./bootstrap.sh      # runs `xcodegen generate`
open Catchbook.xcodeproj
```

Build and run the `Catchbook` scheme on an iOS 17+ simulator or device.

To exercise StoreKit locally without a real App Store Connect product,
run the scheme with the `Catchbook.storekit` configuration enabled
(Xcode does this automatically via the scheme's Run action — see
`project.yml`'s `storeKitConfiguration` setting). Edit
`Catchbook.storekit` in Xcode to tweak the sandboxed unlock product.

## Project layout

```
Sources/     SwiftUI views + app entry point (the Catchbook target)
Shared/      Model, StatsCalculator, LocationProvider, PhotoStore,
             EntitlementStore, SpeciesSuggester — no UI dependencies
Tests/       Unit tests for StatsCalculator and SpeciesSuggester
UITests/     End-to-end XCUITest scenarios
fastlane/    Thin lanes for generate/test/build/beta (see file header
             for the canonical template location)
.gitea/      CI workflow (see file header for the canonical template
             location)
```

## Architecture notes

- **Location is always optional.** `LocationProvider` wraps
  `CLLocationManager` behind a small async facade
  (`requestCurrentLocation() async -> CLLocationCoordinate2D?`) that never
  throws and never blocks saving a catch — denied, restricted, or failed
  location requests all just resolve to `nil`. The "Add location" toggle
  in the log form shows an inline "Location unavailable — enable in
  Settings" note when permission is denied, but the Save button is never
  disabled because of it.
- **UI test determinism without Swift injection.** UI tests drive a
  compiled black-box binary, so they can't hand the app a mock Swift
  object. Instead `LocationProvider` reads `-uiTestMockLocation
  allow|deny` from `ProcessInfo.processInfo.arguments` at launch and
  switches its own internal mode — no `CLLocationManager` is even
  constructed in mock mode. A separate `MockLocationProvider` (conforming
  to the same `LocationProviding` protocol) is also available for direct
  use in future unit tests that need a location dependency without
  touching `ProcessInfo`.
- **`StatsCalculator` is a pure, dependency-injected type** — plain
  `[Catch]` in, a `Calendar` and `now` passed explicitly, `CatchStats`
  out. No SwiftData or UIKit imports, so it's fully unit-testable (see
  `Tests/StatsCalculatorTests.swift`, including month bucketing across a
  year boundary).
- **Photos live on disk, not in the database.** `PhotoStore` saves a
  JPEG under a fresh UUID filename in the app's Documents directory;
  `Catch.photoFilename` stores only that filename.
- **Purchase gating.** `EntitlementStore` wraps StoreKit 2
  (`Product`, `Transaction.currentEntitlements`, `Transaction.updates`).
  `LogCatchView` checks `existingCatches.count >= 10 &&
  !entitlementStore.isUnlocked` before saving; when gated it shows
  `PaywallView` and only completes the save once the purchase (or a
  restore) succeeds.
- **UI test seams.** `-uiTestInMemoryStore` forces an in-memory
  SwiftData store so tests never touch a real device's data.
  `-uiTestPreseedCatches N` inserts N deterministic sample catches at
  launch so the purchase-gate test doesn't need to drive the log form
  ten times.

See `SHIP.md` for the App Store submission checklist.
