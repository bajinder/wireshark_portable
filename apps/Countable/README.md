# Countable

A widget pack for countdowns and habit streaks. SwiftUI + SwiftData + WidgetKit
(AppIntents configuration) + StoreKit 2, iOS 17+.

This source tree was authored without Xcode (no compiler available in that
environment) — see "A note on how this was built" at the bottom before you dig in.

## Requirements

- macOS with Xcode 15 or later (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [fastlane](https://fastlane.tools) if you want to use the `fastlane/` lanes —
  `brew install fastlane` or via Bundler

## Build

```sh
./bootstrap.sh
```

This runs `xcodegen generate` (turning `project.yml` into `Countable.xcodeproj`) and
prints the next manual steps (signing team, App Group, StoreKit configuration). The
`.xcodeproj` is gitignored — **never hand-edit it or commit it**; `project.yml` is the
single source of truth. Re-run `xcodegen generate` (or `bootstrap.sh`) any time you
change `project.yml` or add/remove source files.

Then:

```sh
open Countable.xcodeproj
```

Pick the **Countable** scheme, choose an iPhone simulator (this app is iPhone-only —
iPad layouts are out of scope for v1), and Cmd+R.

### Bundle identifiers

Default: app `com.bajinder.countable`, widget extension
`com.bajinder.countable.widgets`, App Group `group.com.bajinder.countable`. To change
these, see the comment block at the top of `project.yml` — the App Group identifier in
particular needs to stay in sync across three files (both `.entitlements` files and
`Shared/Constants/AppGroup.swift`).

## Project layout

```
project.yml                  XcodeGen spec — the source of truth for the Xcode project
Sources/                     Main app target (SwiftUI views, App entry point)
Shared/                      Compiled into BOTH the app and widget extension targets:
                              SwiftData models, StreakCalculator/CountdownCalculator,
                              EntitlementStore, ModelContainerFactory, AppGroup const.
Widgets/                     CountableWidgetsExtension target: WidgetBundle, the two
                              widgets, AppIntents configuration (entities + intents)
Tests/CountableTests/        Unit tests (pure logic, no SwiftData/UI dependency)
UITests/CountableUITests/    XCUITest flows against the real app
fastlane/                    Thin, env-driven lanes (test/beta/release)
.gitea/workflows/ci.yml      Thin CI workflow
Countable.storekit           Local StoreKit testing configuration
```

`Shared/` is deliberately **not** a framework — it's the same source files added to
multiple targets in `project.yml`. This avoids framework-embedding/module-boundary
overhead for a small app and keeps SwiftData model definitions trivially visible to
both the app and the widget extension.

## Running tests

- In Xcode: Cmd+U (runs `CountableTests` + `CountableUITests`).
- From the command line: `fastlane test` (see `fastlane/Fastfile`; reads `SCHEME` and
  `DEVICE_ID` env vars, defaulting to `Countable` / `iPhone 15`).

`CountableTests` is a standalone, unhosted unit test bundle — it compiles `Shared/`
directly alongside the test sources, so `StreakCalculator` and `CountdownCalculator`
are tested as plain value types with no app launch, no SwiftData store, and no
timezone dependency (tests inject a fixed `Calendar`).

`CountableUITests` drives the real app via `XCUIApplication`, launched with the
`-uiTesting` argument so `CountableApp` uses a throwaway in-memory SwiftData store
(see `Sources/CountableApp.swift`) instead of the real App Group-backed one — every UI
test run starts from a clean slate. The purchase-gate UI test additionally relies on
the scheme's StoreKit Configuration being set to `Countable.storekit` (already wired
up in `project.yml`; see `UITests/CountableUITests/UITestSupport.swift` for details on
re-attaching it manually if that association is ever lost).

## Local StoreKit testing

`Countable.storekit` defines the one-time `com.bajinder.countable.unlock` ($2.99,
non-consumable) product for local testing without an App Store Connect account. The
`Countable` scheme is pre-configured to use it (Product > Scheme > Edit Scheme > Run >
Options > StoreKit Configuration). You can also open `Countable.storekit` directly in
Xcode's StoreKit Transaction Manager to inspect/clear test transactions while
debugging the paywall.

## CI registration

`.gitea/workflows/ci.yml` is intentionally thin: `push` to `main` runs `fastlane test`,
pushing a `v*` tag runs `fastlane beta`. Both jobs target `runs-on: macos-host` and
regenerate the Xcode project from `project.yml` before invoking fastlane.

This app follows the shared CI/fastlane conventions kept in `~/infra/templates` rather
than reinventing them — if you're registering this repo with the CI runner, follow
`~/infra/templates/setup.sh` (registers the macOS host runner, secrets, etc.) instead
of anything Countable-specific. `fastlane/Fastfile` and `.gitea/workflows/ci.yml` here
only wire Countable's own `SCHEME` / `APP_IDENTIFIER` / `DEVICE_ID` values into that
shared shape.

## A note on how this was built

This entire source tree — Swift, project.yml, tests, everything — was written on
Linux with no Xcode available, so nothing here has been compiled. The Swift was kept
deliberately conservative (iOS-17-era APIs only, `ObservableObject`/`@Published` over
`@Observable`, no force-unwraps/`try!` outside of test files, no clever generics) and
cross-checked against Apple's App Intents / WidgetKit documentation where the API
surface was unfamiliar. Still: **build it once locally and skim the compiler output
before you trust it**, especially around the AppIntents `EntityQuery`/`AppEntity`
conformances in `Widgets/Entities/` and the StoreKit Configuration scheme wiring in
`project.yml` — those are the spots most likely to need a small fix-up on a real
Xcode install.
