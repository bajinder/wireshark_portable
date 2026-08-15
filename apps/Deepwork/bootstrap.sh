#!/usr/bin/env bash
# bootstrap.sh
# Deepwork
#
# Generates Deepwork.xcodeproj from project.yml via XcodeGen. Requires
# Xcode + XcodeGen (`brew install xcodegen`) — this only works on macOS.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "ERROR: xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

echo "==> Generating Deepwork.xcodeproj from project.yml ..."
xcodegen generate

echo "==> Done. Open it with: open Deepwork.xcodeproj"
