#!/usr/bin/env bash
# Bootstraps a local checkout for development: makes sure XcodeGen is
# available, then generates Keeply.xcodeproj from project.yml.
#
# Requires Xcode 15+ and macOS — this script (and the project it generates)
# cannot be run or verified from a non-macOS machine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found."
  if command -v brew >/dev/null 2>&1; then
    echo "Installing via Homebrew..."
    brew install xcodegen
  else
    echo "Install Homebrew (https://brew.sh) or XcodeGen (https://github.com/yonaskolb/XcodeGen) manually, then re-run this script."
    exit 1
  fi
fi

echo "Generating Keeply.xcodeproj..."
xcodegen generate

echo "Done. Open Keeply.xcodeproj in Xcode 15+."
echo
echo "One-time manual steps in Xcode (see SHIP.md):"
echo "  1. Set your Development Team under Signing & Capabilities for the Keeply target."
echo "  2. Edit the Keeply scheme -> Run/Test -> Options -> StoreKit Configuration -> Keeply.storekit."
echo "  3. Add In-App Purchase capability to the Keeply target if not already present."
