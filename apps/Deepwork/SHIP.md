# SHIP.md — Deepwork

Everything needed to take Deepwork from "code in this repo" to "on
TestFlight / in the App Store," written for the local CI setup in
`infra/`. Follow `infra/INFRA.md` first if you haven't already (Gitea,
runner, App Store Connect API key, match).

## 0. First build on the Mac (do this before anything else)

This codebase was written on Linux without Xcode. The very first thing to
do on the Mac mini is:

```
cd apps/Deepwork
./bootstrap.sh          # xcodegen generate
open Deepwork.xcodeproj
```

Expect to fix a handful of small things Xcode flags that a from-scratch
read-through couldn't catch (a typo'd SDK symbol, a missing asset, a
signing team selection). See "Spots I'm least sure about" in the delivery
notes for where to look first if something doesn't compile.

Then, before touching StoreKit or Live Activities specifically:

1. Build & run on the iOS 17+ Simulator. Confirm Timer -> History ->
   Settings all render.
2. Run the unit tests (`Cmd+U` or `fastlane test`) — `TimerEngineTests` and
   `HistoryAggregatorTests` should all pass with zero setup.
3. Run on a **physical device** (Live Activities and Dynamic Island don't
   render meaningfully in the Simulator's own UI, and StoreKit purchase
   sheets behave differently there too).

## 1. App Store Connect record

Standard new-app flow:

1. https://appstoreconnect.apple.com -> Apps -> "+" -> New App.
2. Platform: iOS. Name: "Deepwork" (check availability; App Store names
   are unique across the store — you may need a suffix like "Deepwork
   Focus" if taken).
3. Primary language: English (U.S.). Bundle ID: select
   `com.bajinder.deepwork` (register it first in the Developer Portal if
   it's not already there — Certificates, Identifiers & Profiles ->
   Identifiers -> "+" -> App IDs -> pick this exact bundle ID, and while
   there ALSO enable the **Push Notifications** capability if you plan to
   use ActivityKit push updates later — v1 ships with `pushType: nil`
   only, so this is not required for v1, just worth doing once while
   you're in there).
4. SKU: anything unique to you, e.g. `deepwork-ios-2026`.
5. Once created: App Information -> Category = Productivity.

## 2. Creating the one-time unlock IAP ($3.99, `com.bajinder.deepwork.unlock`)

Exact click path in App Store Connect:

1. Your app -> **Monetization** (left sidebar) -> **In-App Purchases** ->
   "+" (or **Features** -> In-App Purchases on older ASC layouts).
2. Type: **Non-Consumable**.
3. Reference Name: `Deepwork Unlock` (internal only, not user-visible).
4. Product ID: `com.bajinder.deepwork.unlock` — **must match exactly**
   what's in `EntitlementStore.unlockProductID` and
   `Deepwork.storekit`.
5. Price: pick the price tier that maps to $3.99 in the US storefront
   (Tier 4 as of recent pricing schedules — ASC shows you the exact USD
   figure per tier, confirm $3.99 there rather than trusting a
   memorized tier number).
6. App Store Localization (required, at least en-US):
   - Display Name: "Deepwork Unlock"
   - Description: "Unlock full session history and custom focus/break
     timer lengths."
7. Add a **Review Screenshot** (Monetization -> this IAP -> Review
   Information): a screenshot of `PaywallView`. Apple requires this for
   every IAP submitted for review, even non-consumables.
8. Save, then **submit the IAP for review together with the app binary**
   the first time (new IAPs attached to a not-yet-reviewed app version
   get reviewed alongside it automatically — you don't need a separate
   submission step for the first release).

Local testing (StoreKit Testing, no App Store Connect round-trip needed):

1. In Xcode, select the `Deepwork` scheme -> Edit Scheme -> Run -> Options
   -> StoreKit Configuration -> `Deepwork.storekit`.
2. Run on Simulator or device. Purchases against `Deepwork.storekit` are
   entirely local/fake — no real money, no network calls, and you can use
   Debug -> StoreKit -> Manage Transactions in Xcode to clear purchases
   between test runs.
3. Once the real product is live in ASC (even in "Ready to Submit"
   state), switch the scheme's StoreKit Configuration back to "None" to
   test against the real (sandbox) App Store instead, using a Sandbox
   Tester Apple ID (Users and Access -> Sandbox -> Testers).

## 3. Live Activity review notes

- **NSSupportsLiveActivities** is set to `true` via `project.yml`'s
  `info.properties` for the app target — confirm it landed in the built
  Info.plist (`Deepwork.app/Info.plist`) before submitting; App Review
  will bounce a Live-Activity-using app that's missing this key.
- No push entitlement is needed for v1 — `LiveActivityManager.start` calls
  `Activity.request(attributes:content:pushType: nil)`, i.e. local-only
  updates. If a future version adds remote push updates to the Live
  Activity, that requires the **Push Notifications** capability +
  `aps-environment` entitlement + APNs auth key, none of which v1 uses.
- Test the **actual lock screen and Dynamic Island** on a physical
  iPhone 14 Pro/15/16-class device (Dynamic Island hardware) AND a
  non-Dynamic-Island device (lock screen banner only) before submitting —
  the Simulator does not reliably reproduce either.
- Exercise pause/resume specifically: start a focus session, lock the
  phone, pause from the app, resume from the app, and confirm the lock
  screen reflects "Paused" and then a correct live countdown again both
  times — this is the trickiest part of the ContentState math
  (`pausedRemaining` non-nil while paused, `endDate` recomputed on resume).
- Confirm the Activity actually **ends** on cancel and on acknowledging a
  finished session — a Live Activity that lingers after the user has
  moved on is a common App Review rejection reason ("remove Live
  Activities when no longer relevant").
- App Review notes field (paste into the submission's "Notes" box): "This
  app uses ActivityKit to show a focus/break timer countdown on the lock
  screen and in the Dynamic Island while a session is running. No push
  notifications are used — the Live Activity is updated locally only."

## 4. Screenshots

Required sizes (App Store Connect will tell you exactly which are
mandatory for your minimum supported device classes — as of iOS 17,
typically 6.9" and 6.5" iPhone display, plus iPad if you ever support it,
which Deepwork v1 does not):

- Timer screen, idle state (shows the big countdown + Start Focus button).
- Timer screen, running state (shows Pause/Cancel + the live countdown).
- Lock screen with the Live Activity visible (take this on a physical
  device — Simulator screenshots of the lock screen are not acceptable to
  Apple's own screenshot guidelines and won't look right anyway).
- History screen with a populated 7-day bar chart and a few tagged
  sessions in the list.
- Paywall screen.

Capture at the device's native resolution (Cmd+S in Simulator, or
side-button+volume-up on device) — do not upscale/pad smaller screenshots.

## 5. Privacy

Deepwork collects **no data** and makes **no network requests** other than
StoreKit's own App Store communication for the purchase. When filling out
App Privacy in App Store Connect (App Privacy -> Get Started):

- **Data Not Collected**: select this — nothing is collected, tracked, or
  linked to identity. All session history and settings live in local
  SwiftData/UserDefaults storage on-device only.
- Privacy Policy URL: still required by App Store Connect even for
  "no data collected" apps as of current policy — a one-paragraph static
  page stating "Deepwork collects no data and makes no network requests
  other than those Apple's own StoreKit performs to process your
  purchase" is sufficient; host it anywhere you control.
- Export compliance: `ITSAppUsesNonExemptEncryption` is set to `false` in
  `project.yml` (Deepwork uses no custom/non-exempt encryption), which
  skips the export compliance question on each build upload.

## 6. CI / fastlane

`fastlane/` and `.gitea/workflows/ci.yml` here are thin, app-specific
copies of the canonical templates at `~/infra/templates` (repo path:
`infra/templates/`) — see the header comment in each file. Push to `main`
runs the `test` lane; pushing a `v*` tag runs the `beta` lane (build +
upload to TestFlight). `release` is a separate manual lane
(`fastlane release`) that uploads metadata but deliberately stops short of
submitting for review — do that submission by hand in App Store Connect
once you've checked the build in TestFlight.

`fastlane/.env.default` is pre-filled with `APP_IDENTIFIER=com.bajinder.deepwork`
and `SCHEME=Deepwork` (safe to commit, not secrets). `fastlane/.env`
(gitignored) needs `DEVICE_ID` plus the shared `ASC_*`/`MATCH_*` secrets —
see `infra/.env.default` for where those come from.
