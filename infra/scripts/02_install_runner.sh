#!/usr/bin/env bash
# infra/scripts/02_install_runner.sh
#
# Installs everything the CI runner needs NATIVELY on macOS via Homebrew
# (no Docker for the runner itself -- jobs need real Xcode + the plugged-in
# iPhone, which a container can't see). Also creates the ~/infra runtime
# directories used throughout this system.
#
# Safe to re-run (brew install is idempotent; mkdir -p is idempotent).
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: this script must run on macOS (the CI Mac mini), not here." >&2
  exit 1
fi

command -v brew >/dev/null 2>&1 || {
  echo "ERROR: Homebrew is not installed. Install it from https://brew.sh first." >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_INFRA_DIR="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

echo "==> Installing act_runner, fastlane, xcodegen, jq via Homebrew ..."
brew install act_runner fastlane xcodegen jq

echo "==> Creating ~/infra runtime directories ..."
mkdir -p "${HOME}/infra/logs"
mkdir -p "${HOME}/infra/keys"      # holds AuthKey_<KEYID>.p8 (App Store Connect API key)
mkdir -p "${HOME}/infra/runner"    # act_runner working directory (.runner, config.yaml, work/)
mkdir -p "${HOME}/infra/templates"

echo "==> Syncing infra/templates -> ~/infra/templates (source of truth is the repo) ..."
# infra/templates/setup.sh (run per-app) expects to live at ~/infra/templates
# alongside its sibling fastlane/ and .gitea/ directories. Keep ~/infra/templates
# a mirror of whatever is checked into this repo so updates here propagate on
# the next install run.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${REPO_INFRA_DIR}/templates/" "${HOME}/infra/templates/"
else
  rm -rf "${HOME}/infra/templates"
  mkdir -p "${HOME}/infra/templates"
  cp -R "${REPO_INFRA_DIR}/templates/." "${HOME}/infra/templates/"
fi

echo "==> Versions installed:"
act_runner --version || true
fastlane --version || true
xcodegen --version || true
jq --version || true

cat <<EOF

==> Done. Installed: act_runner, fastlane, xcodegen, jq
==> Created: ~/infra/logs, ~/infra/keys, ~/infra/runner
==> Synced: ~/infra/templates (fastlane/, .gitea/, setup.sh, act-runner/)

Next steps:
  1. Make sure Xcode is installed and its license accepted:
       sudo xcodebuild -license accept
  2. Get a runner registration token from the Gitea admin UI (Site
     Administration -> Actions -> Runners -> Create new runner), or:
       docker exec gitea gitea actions generate-runner-token
  3. Run: infra/scripts/03_register_runner.sh <token>

EOF
