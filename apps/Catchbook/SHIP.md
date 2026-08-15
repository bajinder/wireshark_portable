# Catchbook — Shipping Checklist

## Privacy strings (Info.plist, set via `project.yml`)

- [x] `NSLocationWhenInUseUsageDescription` — "Catchbook can tag your
      catches with the location where you caught them."
- [x] `NSPhotoLibraryUsageDescription` — "Catchbook can attach a photo of
      your catch from your photo library."
- [x] `NSPhotoLibraryAddUsageDescription` — "Catchbook can save catch
      photos you choose to keep."
- [ ] No camera usage string is included because Catchbook only uses
      `PhotosPicker` (library selection, no live camera capture). If a
      future version adds `UIImagePickerController`/`AVCapture` camera
      capture, add `NSCameraUsageDescription` before shipping.
- [ ] Re-read every string above out loud as a user would see it in the
      system permission prompt before submitting — Apple review checks
      these are accurate and specific to what the app actually does.

## App Privacy (App Store Connect "Privacy" tab)

Location:
- **Data type:** Precise Location
- **Used for:** App Functionality (tagging where a catch was made)
- **Linked to user:** No (stored only locally in the catch record, never
  transmitted anywhere)
- **Used for tracking:** No
- Declare as **collected: No** if you consider on-device-only storage
  "not collected" per Apple's definition (data that stays solely on
  device and is never transmitted off it is generally not "collected"
  for App Privacy purposes) — confirm current Apple guidance before
  submitting, since this policy has shifted before.

Photos:
- Catchbook reads a photo the user explicitly picks via `PhotosPicker`
  (no library-wide access) and writes a copy into the app's own sandbox.
  Nothing is uploaded. Same "not collected" treatment applies.

No other data types apply — Catchbook has no accounts, no network calls,
no analytics/tracking SDKs, no ads.

## In-App Purchase click path

Product: `com.bajinder.catchbook.unlock` — Non-Consumable, $4.99,
"Unlock Catchbook".

1. App Store Connect → App → Features → In-App Purchases → create a
   **Non-Consumable** IAP with product ID
   `com.bajinder.catchbook.unlock`.
2. Set the reference name, display name, description, and $4.99 pricing
   tier to match `Catchbook.storekit` (used for local/sandbox testing;
   App Store Connect is the source of truth for the live product).
3. Add App Review screenshot + review notes: "Tap Log → fill in a
   species → tap Save Catch 11 times to reach the paywall, or tap the
   Log tab and use the in-app path described in the review notes."
4. Verify the paywall appears exactly on the **11th** catch, not the
   10th or 12th (see `LogCatchView.freeCatchLimit` and
   `UITests/CatchbookUITests.swift testPurchaseGateShowsOnEleventhCatch`).
5. Test the purchase and "Restore Purchases" flows in Sandbox with a
   dedicated Sandbox Apple ID before submission.
6. Confirm the unlock persists across reinstall via Restore Purchases
   (StoreKit 2 `AppStore.sync()` + `Transaction.currentEntitlements`).

## Screenshots

- [ ] Log tab — empty form
- [ ] Log tab — filled form with a photo and "Add location" toggled on
- [ ] List tab — several catches with thumbnails
- [ ] Map tab — pins for located catches
- [ ] Stats tab — monthly bar chart + biggest-by-species list
- [ ] Paywall — shown mid-flow on the 11th catch
- [ ] Capture on at least one 6.7" and one 5.5" simulator/device per App
      Store Connect's required screenshot sizes.

## Pre-submission smoke checklist

- [ ] Deny location permission on a clean install; confirm the app is
      fully usable and saving still works (see `README.md` — "Location
      is always optional").
- [ ] Log 10 catches, confirm no paywall; log an 11th, confirm the
      paywall appears; purchase (sandbox) and confirm the 11th catch
      then saves.
- [ ] Force-quit and relaunch; confirm previously logged catches, photos,
      and the unlock all persist.
- [ ] Run `Tests/` and `UITests/` targets on a clean simulator.
- [ ] `ITSAppUsesNonExemptEncryption` is set to `false` in `project.yml`
      (Catchbook uses no custom encryption) — confirm this still matches
      reality before archiving.
