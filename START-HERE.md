# iOS Factory — Local CI + 4 Apps (Start Here)

This branch delivers the complete codebase for the "Local CI + 4 iOS Apps" handover:

| Piece | Path | What it is |
|---|---|---|
| Prompt 0 — Local CI | `infra/` | Gitea (Docker) + native macOS act_runner + launchd + fastlane/match templates + `INFRA.md` runbook |
| App 1 — Countable | `apps/Countable/` | Countdown + habit-streak widget pack (WidgetKit, AppIntents, SwiftData, StoreKit 2) |
| App 2 — Deepwork | `apps/Deepwork/` | Pomodoro timer with Live Activities (ActivityKit, Swift Charts) |
| App 3 — Keeply | `apps/Keeply/` | Receipt + warranty tracker (Vision OCR, local notifications) |
| App 4 — Catchbook | `apps/Catchbook/` | Fishing catch log (CoreLocation, MapKit, Swift Charts) |

Each app directory is **self-contained** — it is designed to be copied out and pushed
into its own repo on your local Gitea, exactly as the handover doc intended.

## What was verified here, and what wasn't

This codebase was authored and reviewed in a Linux environment **without Xcode, macOS,
Docker, or a connected iPhone**. That means:

- ✅ All source, tests, configs, and scripts are complete and internally reviewed.
- ❌ `xcodebuild` has **not** been run; device tests have **not** been run; the Gitea
  pipeline has **not** been observed green. The first build on the Mac mini is the
  real verification step, and minor compile fixes there are expected and normal.

Projects are defined with **XcodeGen** (`project.yml` in each app) because `.xcodeproj`
files cannot be authored reliably by hand. `bootstrap.sh` in each app runs
`xcodegen generate` for you (XcodeGen is installed by the infra scripts).

## Order of operations on the Mac mini

1. **Infra first.** Follow `infra/INFRA.md` top to bottom. It flags every manual step:
   Gitea admin creation, runner registration token, App Store Connect API key (.p8),
   match passphrase, iPhone Developer Mode + first device trust.
2. **Get your device id:** `xcrun devicectl list devices` and put it in each app's
   `.env` (`DEVICE_ID=...`). The apps ship with `<PASTE_DEVICE_ID>` placeholders.
3. **App 1 (Countable) fully first:** `cd apps/Countable && ./bootstrap.sh`, open the
   generated project, fix anything Xcode complains about, get tests green locally,
   then run `~/infra/templates/setup.sh`, push to local Gitea, and confirm the
   pipeline goes green in the Actions UI. Ship it (see its `SHIP.md`), then repeat
   for Deepwork → Keeply → Catchbook.

## Conventions shared by all four apps

- iOS 17 minimum, SwiftUI + SwiftData, StoreKit 2 non-consumable unlock with a
  bundled `.storekit` file for local testing.
- Bundle ids default to `com.bajinder.<app>` — change in `project.yml` if needed.
- Pure, unit-tested calculators for all business math (streaks, countdowns, timer
  state machine, expiry dates, stats) — no date math in views.
- XCUITests use launch arguments (in-memory stores, mocks, short timers) so they run
  deterministically on the physical device.
- Thin per-app `fastlane/` + `.gitea/workflows/ci.yml` matching the canonical
  templates in `infra/templates/` (push to `main` → `test` lane on the device;
  tag `v*` → `beta` lane → TestFlight).
