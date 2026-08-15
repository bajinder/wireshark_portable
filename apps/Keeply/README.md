# Keeply

Snap a receipt, track the warranty, get reminded before it expires.

Keeply is a small, single-purpose iOS app: photograph or pick a receipt,
let on-device OCR guess the purchase date and total, set a warranty
length, and Keeply reminds you 30 and 7 days before it lapses. Free tier
tracks up to 5 items; a one-time in-app purchase unlocks unlimited items.

Everything runs on-device. No accounts, no server, no analytics.

## Requirements

- macOS with Xcode 15 or later (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- This project **cannot** be built or run on Linux/Windows — Xcode and the
  iOS Simulator are macOS-only. It was authored on Linux without a
  compiler available, so treat the first Xcode build as the first real
  compile check (see `SHIP.md` for what to verify).

## Getting started

```sh
./bootstrap.sh   # installs XcodeGen if missing, runs `xcodegen generate`
open Keeply.xcodeproj
```

Then, one-time, in Xcode:

1. Select the `Keeply` target -> Signing & Capabilities -> set your
   Development Team.
2. Edit the `Keeply` scheme -> Run and Test actions -> Options ->
   StoreKit Configuration -> select `Keeply.storekit`. This lets the
   paywall load a real price locally without hitting App Store Connect.
3. Build & run on a simulator or device (iOS 17+).

Re-run `xcodegen generate` (or `./bootstrap.sh`) any time `project.yml`
changes — `Keeply.xcodeproj` is generated and intentionally not committed
(see `.gitignore`).

## Project layout

```
Keeply/
  project.yml            XcodeGen project definition (app + 2 test targets)
  bootstrap.sh            One-shot local setup script
  Keeply.storekit          StoreKit Testing Configuration (1 non-consumable)
  SampleReceipts/          3 generated JPEGs used by the UI test bypass
  Sources/                 App target: SwiftUI views + app entry point
    KeeplyApp.swift
    Views/
      ItemListView.swift        List, search, sort-by-soonest-expiry
      ItemRowView.swift         Row: thumbnail, name, expiry, days-left badge
      ItemDetailView.swift      Full photo + editable fields + delete
      PaywallView.swift         StoreKit 2 purchase screen
      AddItemFlow/
        AddItemView.swift        Orchestrates pick -> OCR -> form
        ItemFormView.swift       Shared editable form (name/date/warranty/amount)
        CameraPickerView.swift   UIImagePickerController wrapper for the camera
    Assets.xcassets/         App icon + accent color
  Shared/                   Pure/testable + infrastructure types
    Item.swift                @Model — SwiftData entity
    WarrantyOption.swift       6m/1y/2y/3y/custom enum
    ReceiptParser.swift         [String] -> ParsedReceipt (pure, testable)
    ExpiryCalculator.swift      Calendar-injected date math (pure, testable)
    TextRecognizer.swift        Vision OCR wrapper (async, off-main-actor)
    NotificationScheduler.swift UNUserNotificationCenter wrapper (protocol-backed)
    PhotoStore.swift            JPEG save/load/delete in Documents
    EntitlementStore.swift      StoreKit 2 purchase state
  Tests/KeeplyTests/         Unit tests (ReceiptParser, ExpiryCalculator, NotificationScheduler spy)
  UITests/KeeplyUITests/     UI tests (add item, OCR-failure path, paywall gate, search)
  fastlane/                 Fastfile/Appfile (generate_project, test, build, release lanes)
  .gitea/workflows/ci.yml    CI: xcodegen generate -> xcodebuild test
```

## How the pieces fit together

- **Add flow** (`AddItemView`): pick a source (camera via
  `UIImagePickerController`, or the photo library via `PhotosPicker`),
  run OCR (`TextRecognizer`, Vision `VNRecognizeTextRequest`, entirely
  on-device), parse the recognized lines with `ReceiptParser` to guess a
  purchase date and total, then show `ItemFormView` pre-filled and
  user-correctable. OCR/parse failures never block the flow — the form
  just opens empty with a "Couldn't read receipt — enter details
  manually" note.
- **Warranty math** (`ExpiryCalculator`): `purchaseDate + warrantyMonths`,
  clamped to the end of the target month (Jan 31 + 1 month = Feb 28, not
  a spillover into March), plus 30/7-day notification trigger dates that
  skip anything already in the past.
- **Notifications** (`NotificationScheduler`): requests permission on
  every item save (harmless after the first grant/denial — the system
  just returns the existing status), schedules up to two
  `UNCalendarNotificationTrigger` requests per item, cancels and
  re-schedules on edit, cancels on delete.
- **Storage**: item metadata lives in SwiftData (`Item`); the receipt
  photo itself is a JPEG in the app's Documents directory, named
  `<item UUID>.jpg`, managed by `PhotoStore`. Only the filename is stored
  in SwiftData.
- **Purchases** (`EntitlementStore`): StoreKit 2, one non-consumable
  product (`com.bajinder.keeply.unlock`, $4.99). Adding a 6th item
  without the unlock shows `PaywallView` instead of the add-item sheet.

## Deterministic UI testing without a scriptable picker

XCUITest cannot reliably drive the system Photos picker or camera across
simulators/devices. Instead:

- `SampleReceipts/*.jpg` (repo root of the app) are bundled into **both** the app target
  and the UI test target (via the shared `SampleReceipts/` resource
  folder referenced from both target's `resources:` in `project.yml`).
- Launching the app with `-uiTestUseSampleImage` makes `AddItemView` skip
  source-picking, load a bundled sample image via `Bundle.main`, and run
  it straight through OCR into the form — deterministically, with no UI
  scripting of the system picker required.
- `-uiTestSampleImageName <name>` (read via
  `UserDefaults.standard.string(forKey:)`, the standard `-key value`
  launch-argument convention) selects which bundled sample to use:
  `sample_receipt_1`, `sample_receipt_2` (real receipt text, exercises
  OCR + `ReceiptParser`), or `sample_blank` (no text, exercises the
  OCR-failure -> manual entry path).
- `-uiTestResetData` makes `KeeplyApp` use an in-memory SwiftData store
  so each UI test run starts from zero items.

This deliberately does **not** attempt to fake `PhotosPicker` or
`UIImagePickerController` themselves — those remain exactly what ships
to users. It only gives the UI test a deterministic way to get a photo
into the flow.

## Running tests from the command line

```sh
cd apps/Keeply
xcodegen generate
xcodebuild test -project Keeply.xcodeproj -scheme Keeply \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

or via fastlane: `bundle exec fastlane ios test`.

## Privacy

Keeply collects nothing and talks to no server. Receipt photos and item
data stay in the app's local sandbox (SwiftData store + Documents
directory) and are never uploaded anywhere. See `SHIP.md` for the App
Store privacy label mapping.
