# Countable — App Store shipping checklist

Manual steps only. Nothing here is automated by `fastlane/` yet (v1 lanes only build
and upload — App Store Connect record/product setup is click-path, done once).

## 1. Create the app record (App Store Connect)

1. https://appstoreconnect.apple.com → Apps → **+** → New App.
2. Platform: iOS. Name: **Countable** (check availability; append a suffix if taken).
3. Primary language: English (U.S.).
4. Bundle ID: select `com.bajinder.countable` (register it under Certificates,
   Identifiers & Profiles first if it doesn't show up yet — enable the **App Groups**
   capability on it there, and register/enable App Groups on the
   `com.bajinder.countable.widgets` identifier too, both pointing at
   `group.com.bajinder.countable`).
5. SKU: any unique internal string, e.g. `countable-ios-v1`.
6. User access: Full Access (adjust per your team).

## 2. Create the in-app purchase

1. App Store Connect → your app → **Features > In-App Purchases** → **+**.
2. Type: **Non-Consumable**.
3. Reference Name: `Countable Unlock`.
4. Product ID: `com.bajinder.countable.unlock` — **must match exactly** what's in
   `Shared/Entitlements/StoreConstants.swift` and `Countable.storekit`.
5. Price: tier corresponding to **$2.99 USD** (Apple manages the price tier / other
   currencies from there).
6. App Store localization (English, at minimum):
   - Display Name: `Unlock Countable`
   - Description: `Unlock unlimited countdowns and habits in Countable.`
7. Review screenshot: attach a screenshot of the paywall sheet (`PaywallView`) — App
   Review requires this for every IAP.
8. Save, then submit the IAP for review alongside the first app version (non-consumable
   IAPs on a brand-new app version are reviewed together with the binary).

## 3. Screenshots

Required sizes (iPhone-only app — no iPad screenshots needed since iPad layouts are
out of scope for v1):

- 6.9" display (iPhone 16 Pro Max class) — required
- 6.5" display (iPhone 11 Pro Max / XS Max class) — required if you support older
  device screenshot fallback; otherwise 6.9" alone may suffice depending on current App
  Store Connect requirements at submission time — check the current matrix, it changes.

Suggested shots (3–5 total):

1. Countdown list with 2–3 items, varied accent colors.
2. Countdown edit sheet showing title/date/emoji/accent color picker.
3. Habit list with an active streak (e.g. "12 day streak").
4. Home Screen with the small + medium countdown widgets and the small habit widget
   placed together.
5. The paywall sheet.

Generate these on a real Mac/simulator (`fastlane snapshot` is not wired up in v1's
`Fastfile` — add it if you want automated screenshots; for a first submission, manual
Simulator screenshots via Cmd+S are fine).

## 4. Privacy labels (App Privacy section)

Countable v1 has no accounts, no analytics SDK, no network calls other than StoreKit
itself talking to Apple. Answer:

- **Data Collected: No, we do not collect any data from this app.**

If you later add analytics/crash reporting, revisit this — this checklist reflects the
v1 scope only (no accounts, no sync, no notifications).

## 5. App Review notes

Paste something like this into the "Notes" field for the review team:

> Countable is a local-only countdown/habit-streak tracker with Home Screen widgets.
> All data is stored on-device (SwiftData) inside an App Group shared with the widget
> extension; there is no backend, no account system, and no network access other than
> StoreKit.
>
> The app includes one non-consumable IAP, "Countable Unlock"
> (com.bajinder.countable.unlock, $2.99), which removes the free-tier limit of 3
> combined countdowns/habits. To test: add 3 countdowns or habits (the + button works
> normally), then attempt to add a 4th — the paywall sheet appears with the purchase
> button. Use a Sandbox Apple ID to complete a test purchase; "Restore Purchases" is
> available on the paywall.
>
> Widgets: long-press the Home Screen > Edit Widgets > search "Countable" to add the
> Countdown (small/medium) or Habit Streak (small) widget, then long-press the widget >
> Edit Widget to pick which countdown/habit it displays.

## 6. Version metadata checklist (quick pass before submitting)

- [ ] Marketing version / build number bumped (`MARKETING_VERSION` /
      `CURRENT_PROJECT_VERSION` in `project.yml`)
- [ ] Real app icon added to `Sources/Resources/Assets.xcassets/AppIcon.appiconset`
      (this repo ships that asset catalog entry empty — no icon has been designed yet)
- [ ] Support URL + marketing URL (or omit marketing URL) filled in on App Store
      Connect
- [ ] Age rating questionnaire completed (should be 4+, no objectionable content)
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption` is already set to `false` in
      `project.yml`'s Info.plist properties for the app target, so no manual answer is
      needed at submission for standard encryption
- [ ] IAP attached to this version and both submitted together
