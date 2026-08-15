#!/usr/bin/env bash
set -euo pipefail

# Countable — bootstrap script.
# Run this on a Mac with Xcode 15+ and XcodeGen installed.
#
# 1. Generates Countable.xcodeproj from project.yml via XcodeGen.
# 2. Prints next steps for opening, signing, and testing the project.

cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found." >&2
  echo "Install it with: brew install xcodegen" >&2
  exit 1
fi

echo "==> Generating Countable.xcodeproj from project.yml"
xcodegen generate

cat <<'EOF'

Countable.xcodeproj generated.

Next steps:
  1. open Countable.xcodeproj
  2. Select the "Countable" scheme and an iPhone simulator, then Cmd+R to run.
  3. Signing: the Countable and CountableWidgetsExtension targets use automatic
     signing. Pick your Team in each target's Signing & Capabilities tab. Make sure
     the App Group "group.com.bajinder.countable" is enabled for BOTH targets — the
     entitlements files are already checked in, you're just attaching a team so
     Xcode can provision it.
  4. StoreKit testing: the "Countable" scheme is pre-wired to Countable.storekit for
     local testing (no App Store Connect / sandbox account needed). If that
     association doesn't survive project generation on your machine, reattach it via
     Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration.
  5. Tests: Cmd+U runs CountableTests (unit) + CountableUITests (UI). From the
     command line: `cd fastlane && bundle exec fastlane test` (or just
     `fastlane test` if fastlane is installed globally).
  6. Changing bundle identifiers: see the comment at the top of project.yml — a few
     places (App Group id especially) must be kept in sync by hand.

EOF
