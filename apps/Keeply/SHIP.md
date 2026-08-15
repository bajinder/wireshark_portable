# Keeply — Ship Checklist

This app was authored on Linux without access to Xcode or a Swift
compiler. Every file is written to be conservative, dependency-light
Swift that should compile first-try on Xcode 15 / iOS 17 SDK, but **the
first Xcode build on macOS is the real compile check** — budget time for
that before assuming anything below is done.

## Before the first build

- [ ] Open on macOS with Xcode 15+ installed.
- [ ] Run `./bootstrap.sh` (or `xcodegen generate`) to produce
      `Keeply.xcodeproj` from `project.yml`.
- [ ] Build the `Keeply` scheme for a simulator. Fix any compiler errors —
      see "Spots I'm least sure about" below for where to look first.
- [ ] Run the unit test target (`KeeplyTests`) — no device/simulator
      permissions needed, should be green immediately.
- [ ] Run the UI test target (`KeeplyUITests`) on a simulator.

## Signing & capabilities

- [ ] Set a Development Team on the `Keeply` target (Signing &
      Capabilities).
- [ ] Confirm the bundle identifier is `com.bajinder.keeply` (set via
      `project.yml`; don't need to touch this unless renaming the app).
- [ ] In App Store Connect, create the app record with bundle ID
      `com.bajinder.keeply` if it doesn't already exist.

## In-App Purchase (StoreKit 2) — click path

1. App Store Connect -> your app -> **Monetization -> In-App Purchases**
   -> **+** -> **Non-Consumable**.
2. Reference Name: `Keeply Unlock` (internal only).
3. Product ID: `com.bajinder.keeply.unlock` — **must match exactly**,
   this is hardcoded in `EntitlementStore.unlockProductID`.
4. Price: select the tier matching **$4.99 USD** (Apple's price tiers
   auto-localize to other storefronts).
5. Add at least one localization (Display Name: "Unlock Unlimited
   Items", Description: a sentence about tracking unlimited warranties).
6. Upload a review screenshot showing the paywall (`PaywallView`).
7. Submit the IAP for review alongside the app's first version — new IAPs
   attached to a not-yet-approved app version are reviewed together.
8. Locally, before any of this exists in App Store Connect: edit the
   `Keeply` scheme -> Run/Test -> Options -> **StoreKit Configuration**
   -> `Keeply.storekit`, so `Product.products(for:)` resolves during
   development and simulator/UI testing without a live App Store
   Connect record.

## Permissions & Info.plist

These are generated into the app's Info.plist via `project.yml`, no
manual Xcode step needed — just confirm they're present and read
naturally after the first build:

- [ ] `NSCameraUsageDescription` — "Keeply uses the camera to
      photograph receipts."
- [ ] `NSPhotoLibraryUsageDescription` — "Keeply uses your photo library
      so you can attach an existing receipt photo to a warranty item."
- [ ] Notification permission has **no** Info.plist key requirement (it's
      requested at runtime via `UNUserNotificationCenter`) — verify the
      system prompt appears the first time a user saves an item
      (`NotificationScheduler.requestAuthorization()` is called from
      `AddItemView.scheduleNotifications(for:)`).

## Manual on-device verification (cannot be automated/simulated here)

- [ ] **Live camera OCR accuracy.** `TextRecognizer` and `ReceiptParser`
      are unit-tested against synthetic `[String]` fixtures, but real
      Vision OCR output on a real photographed receipt (lighting, glare,
      receipt paper texture, thermal-print fading) has not been — and
      cannot be, from this environment — verified. **A human must**:
      - Photograph a handful of real receipts (different stores, fonts,
        thermal vs. inkjet) on a real device.
      - Confirm the purchase date and total prefill reasonably often,
        and that garbled/no OCR text degrades cleanly to the manual-entry
        note rather than crashing or hanging.
      - Tune `ReceiptParser`'s keyword list / date formats if a common
        real-world receipt format is consistently missed.
- [ ] Camera permission prompt and denial-recovery path (Settings deep
      link is not implemented in v1 — confirm the picker source buttons
      degrade sensibly, e.g. tapping "Take Photo" with camera access
      denied should not crash; iOS handles the system alert).
- [ ] Photo library permission prompt via `PhotosPicker` (this uses the
      limited-access picker UI, which doesn't require
      `NSPhotoLibraryUsageDescription` to be *shown* by the system picker
      itself, but the key must still be present for any programmatic
      library access — confirmed present above).
- [ ] Notification permission prompt appears once, at first item save,
      and that the 30-day/7-day local notifications actually fire at the
      expected wall-clock time (9:00 AM local time on the trigger date)
      on a real device — simulators are unreliable for local notification
      delivery timing.
- [ ] Real StoreKit 2 purchase flow end-to-end in TestFlight/Sandbox
      (the `.storekit` file only exercises the local simulation).

## Privacy labels (App Store Connect -> App Privacy)

Keeply collects **no data** and makes **no network calls**:

- Data collection: **"Data Not Collected"** — no analytics, no crash
  reporting SDK, no third-party frameworks, no server calls (OCR is
  on-device Vision; purchases go directly through StoreKit).
- Photos: captured/picked receipt photos are written only to the app's
  local Documents directory and are never uploaded, synced, or shared.
  They are deleted from disk when the corresponding item is deleted
  (`PhotoStore.delete`, called from `ItemDetailView.deleteItem`).
- Item data (name, date, amount, warranty length): stored only in the
  on-device SwiftData store. No iCloud sync, no account, no export.
- If asked whether any data is "linked to the user's identity" — no,
  there is no identity in this app at all.

## Spots I'm least sure about (read before debugging build errors)

In rough order of where I'd look first if the build doesn't compile
clean:

1. **`DatePicker(..., in: ...Date(), ...)`** in `ItemFormView.swift` and
   `ItemDetailView.swift` — I'm relying on the `PartialRangeThrough<Date>`
   overload of `DatePicker.init(_:selection:in:displayedComponents:)`
   existing. I'm fairly confident it does (it's a standard SwiftUI
   overload), but if the compiler can't resolve it, swap to a
   `ClosedRange<Date>` (e.g. `Date.distantPast...Date()`).
2. **`ExpiryCalculator.expiryDate`** deliberately does its own month/day
   clamping arithmetic instead of calling
   `Calendar.date(byAdding:to:)`, because that API's default matching
   policy can roll an overflowing day (Jan 31 + 1 month) into the
   *following* month instead of clamping to the month's last day. The
   hand-rolled version is more code but removes that ambiguity — see the
   comment in the file and `ExpiryCalculatorTests` for the exact
   expected behavior at month boundaries.
3. **`NotificationScheduler`** wraps `UNUserNotificationCenter` through a
   hand-written protocol (`UserNotificationCenterProtocol`) using the
   older completion-handler APIs (`requestAuthorization(options:
   completionHandler:)`, `add(_:withCompletionHandler:)`) bridged to
   `async` manually via `withCheckedContinuation`, rather than assuming
   `UNUserNotificationCenter` has native `async throws` overloads for
   every method. This is slightly more verbose but avoids guessing at an
   API surface I couldn't verify against the real SDK headers from this
   environment.
4. **`Bundle.main.url(forResource:withExtension:)`** for the
   `-uiTestUseSampleImage` bypass in `AddItemView.swift` depends on
   `SampleReceipts/` actually landing in the **app** target's bundle
   (not just the UI test target's). This is wired via `project.yml`
   listing the same `SampleReceipts` path under `resources:` for both
   the `Keeply` and `KeeplyUITests` targets — double check the built
   `Keeply.app` bundle actually contains `sample_receipt_1.jpg` etc. at
   its root after a build if the UI tests can't find them.
5. **`@Bindable var item: Item`** in `ItemDetailView.swift`, assigned via
   a custom `init(item:)` — this depends on SwiftData's `@Model` macro
   making `Item` conform to `Observable` (true as of iOS 17's SwiftData),
   which is what makes `@Bindable` valid here. Standard pattern, but
   worth a second look if `ItemDetailView` doesn't compile.
6. **StoreKit Configuration** is not wired into `project.yml`'s scheme —
   XcodeGen's YAML schema for a scheme-level "StoreKit Configuration"
   setting isn't something I could confidently verify the exact key
   name/shape for without Xcode to test against, so it's a manual
   one-time step in Xcode instead (see "Getting started" in README.md /
   step 4 above). Without it, `PaywallView` will show "Loading…"
   indefinitely in Simulator/UI tests since `Product.products(for:)`
   has nothing to resolve against.
7. **`ReceiptParser`**'s date disambiguation (US MM/dd vs. European
   dd/MM) relies on `DateFormatter.isLenient = false` rejecting
   out-of-range values (e.g. refusing to parse "31" as a month). This is
   documented, standard `DateFormatter` behavior, but it's the crux of
   `testEuropeanDayFirstDateFallsBackWhenMonthIsInvalidAsUSFormat` in
   `ReceiptParserTests.swift` — worth confirming that test actually
   passes on first run.

## Explicitly out of scope for v1 (do not add without a product decision)

Accounts/sign-in, cloud/iCloud sync, PDF export, categories/tags,
multi-currency conversion logic. All deliberately absent per the v1
spec.
