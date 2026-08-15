# Deepwork

A Pomodoro-style focus timer for iOS with a lock-screen / Dynamic Island Live
Activity, local session history, and a one-time unlock for full history +
custom timer lengths.

Built with SwiftUI, SwiftData, ActivityKit, Swift Charts, and StoreKit 2.
iOS 17.0+. No accounts, no sync, no analytics, no network access at all.

## Status

Authored and reviewed on Linux, **without Xcode**. Nothing here has been
compiled or run yet — the first `xcodegen generate` + build on a Mac is the
real verification step. See `SHIP.md` for what to check first.

## Project layout

```
apps/Deepwork/
  project.yml              XcodeGen project definition (source of truth —
                            Deepwork.xcodeproj is generated, gitignored)
  bootstrap.sh              Runs `xcodegen generate`
  Deepwork.storekit         Local StoreKit Testing config for the unlock IAP

  Sources/                  App target: SwiftUI views + app-level view model
    DeepworkApp.swift         @main entry point, SwiftData container, scenePhase rehydration
    RootView.swift             TabView: Timer / History / Settings
    TimerView.swift            Big countdown, start/pause/resume/cancel, tag entry
    TimerViewModel.swift       Wires TimerEngine <-> persistence <-> Live Activity <-> SwiftData
    HistoryView.swift          7-day Swift Charts bar chart + session list
    SettingsView.swift         Timer length config (gated by purchase)
    PaywallView.swift          StoreKit 2 purchase/restore UI
    Assets.xcassets/

  Shared/                   Compiled into BOTH the app and the widget
                            extension — kept dependency-light and pure
    TimerEngine.swift              Pure state machine: idle/running/paused/finished
    TimerEngine+Persistence.swift  Codable round-trip through UserDefaults
    Session.swift                  SwiftData @Model for one completed interval
    HistoryAggregator.swift        Pure "minutes per day" math (Calendar-injected)
    DeepworkActivityAttributes.swift  ActivityKit attributes/content state
    LiveActivityManager.swift      Starts/updates/ends the Live Activity
    EntitlementStore.swift         StoreKit 2 one-time purchase wrapper

  ActivityWidget/           Widget extension target (com.bajinder.deepwork.activity)
    DeepworkActivityWidgetBundle.swift
    DeepworkLiveActivityWidget.swift   Lock screen + Dynamic Island (compact/expanded)

  Tests/                    Unit tests (XCTest, @testable import Deepwork)
    TimerEngineTests.swift
    HistoryAggregatorTests.swift

  UITests/                  XCUITest, launch-argument driven
    DeepworkUITests.swift

  fastlane/, .gitea/workflows/ci.yml   Thin copies of the shared CI conventions
                                        (canonical templates: ~/infra/templates)
```

## Architecture: why the timer survives backgrounding/kill/relaunch

The timer is **never** "a `Timer` that ticks in memory." `TimerEngine`
(`Shared/TimerEngine.swift`) is a pure state machine:

```
idle
  -> running(phase, startDate, endDate)   // endDate is authoritative
  -> paused(phase, remaining)             // remaining is frozen at pause time
  -> finished(phase, startDate, endDate)  // endDate already passed
```

Every transition (`start`/`pause`/`resume`/`cancel`/`refresh`) is a pure
function of the current state and an injected `now: () -> Date` closure —
there's no ticking involved at all. `TimerViewModel` persists the state to
`UserDefaults` as Codable JSON after every transition, and mirrors it into
its own `@Observable`-tracked `timerState` property (see the file-level
comment in `TimerViewModel.swift` for why that mirror exists — nesting a
plain `TimerEngine` object inside an `@Observable` class does **not** make
mutations to the engine's internals reactive on its own).

On launch and on every foreground transition (`scenePhase == .active`),
`DeepworkApp` calls `TimerViewModel.rehydrate()`, which:

1. Calls `engine.refresh()` — if a `.running` interval's `endDate` has
   already passed (however long the app was gone), the state machine
   transitions to `.finished` right there, using the *real* elapsed time,
   not whatever the UI last showed.
2. Records a `Session` in SwiftData for a newly-`.finished` interval
   (de-duplicated by `endDate` so this is safe to call repeatedly).
3. Re-syncs the Live Activity to match.

`TimerView` also runs a lightweight polling `.task` (1s `Task.sleep` loop,
tied to the view's lifecycle) that calls `rehydrate()` while the timer
screen is visible, purely so the "session finished" alert appears promptly
without requiring the user to background/foreground the app. This is
explicitly **not** the correctness mechanism — it's commented as such in
`TimerView.swift` — recoverability after a kill/relaunch is guaranteed by
step 1-3 above regardless of whether this loop ever runs.

The on-screen countdown itself uses `Text(timerInterval:countsDown:)`
driven directly by `startDate...endDate`, which the system keeps
live-updating without any app code ticking a clock.

## Live Activity

`LiveActivityManager` starts/updates/ends a single
`Activity<DeepworkActivityAttributes>` mirroring `TimerEngine`'s state:
`ContentState` carries `phase`, `endDate`, and `pausedRemaining:
TimeInterval?` (non-nil exactly while paused). The widget extension
(`ActivityWidget/DeepworkLiveActivityWidget.swift`) renders the lock screen
banner and both Dynamic Island states (compact leading icon / trailing
countdown, expanded with a paused indicator) purely from that content
state — it has no logic of its own.

## Free vs. unlocked

| | Free | Unlocked ($3.99 one-time) |
|---|---|---|
| Timer lengths | Fixed presets (25/5, 50/10, 15/3) | Custom, 5-120 / 1-60 min |
| History | Last 7 days | Full history |
| Tags | Yes | Yes |
| Live Activity | Yes | Yes |

`EntitlementStore` treats `Transaction.currentEntitlements` as the source
of truth (not a cached local bool), and observes `Transaction.updates`
continuously so a purchase completed outside the app is picked up without
a relaunch.

## Running tests locally (on a Mac, once bootstrapped)

```
cd apps/Deepwork
./bootstrap.sh
fastlane test          # or: xcodebuild test -scheme Deepwork ...
```

UI tests pass `-uiTestShortTimer` (read by `TimerViewModel`) to shrink the
focus/break length to 5 seconds so "session finished" flows don't require a
25-minute wait.
