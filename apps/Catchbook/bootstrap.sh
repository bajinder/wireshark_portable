#!/bin/bash
#
# bootstrap.sh — generates Catchbook.xcodeproj from project.yml via XcodeGen.
#
# Requires Xcode 15+ and XcodeGen (https://github.com/yonaskolb/XcodeGen):
#   brew install xcodegen
#
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen not found on PATH." >&2
  echo "       install it with: brew install xcodegen" >&2
  exit 1
fi

echo "Generating Catchbook.xcodeproj from project.yml…"
xcodegen generate

echo "Done. Open Catchbook.xcodeproj in Xcode 15+ to build and run."
