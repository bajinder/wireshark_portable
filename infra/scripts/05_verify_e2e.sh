#!/usr/bin/env bash
# infra/scripts/05_verify_e2e.sh
#
# End-to-end smoke test of the whole pipeline: generates a throwaway
# hello-world iOS app with XcodeGen, wires it up with
# infra/templates/setup.sh, creates a repo in the local Gitea instance,
# pushes it, waits for Gitea Actions to run the "test" lane on the
# macos-host runner, prints PASS/FAIL, and deletes the throwaway repo
# either way.
#
# Code signing is deliberately disabled in the generated project
# (CODE_SIGNING_ALLOWED=NO) -- this script verifies the *pipeline wiring*
# (Gitea -> Actions -> runner -> xcodegen -> fastlane -> simulator or
# device test run), not match/signing, which has its own manual
# verification path documented in infra/INFRA.md.
#
# Required env:
#   GITEA_TOKEN        Gitea API token (repo scope) -- see infra/.env.default
#   GITEA_ADMIN_USER   Gitea username to create the throwaway repo under
# Optional env:
#   GITEA_INSTANCE_URL default: http://localhost:3000
#   DEVICE_ID          if set and the device is attached, tests run on it;
#                       otherwise the Fastfile falls back to a simulator.
#   POLL_TIMEOUT_SECS  default: 900 (15 min -- real-device Xcode builds are slow)
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: this script must run on macOS (the CI Mac mini), not here." >&2
  exit 1
fi

: "${GITEA_TOKEN:?ERROR: GITEA_TOKEN must be set (see infra/.env.default)}"
: "${GITEA_ADMIN_USER:?ERROR: GITEA_ADMIN_USER must be set (see infra/.env.default)}"

GITEA_INSTANCE_URL="${GITEA_INSTANCE_URL:-http://localhost:3000}"
POLL_TIMEOUT_SECS="${POLL_TIMEOUT_SECS:-900}"
POLL_INTERVAL_SECS=10

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_INFRA_DIR="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
SETUP_SH="${HOME}/infra/templates/setup.sh"
[ -x "${SETUP_SH}" ] || SETUP_SH="${REPO_INFRA_DIR}/templates/setup.sh"

command -v xcodegen >/dev/null 2>&1 || { echo "ERROR: xcodegen not found. Run 02_install_runner.sh." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not found. Run 02_install_runner.sh." >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found." >&2; exit 1; }

RUN_ID="$(date +%Y%m%d%H%M%S)"
REPO_NAME="e2e-verify-${RUN_ID}"
APP_NAME="E2EHelloWorld"
APP_IDENTIFIER="com.local.e2e.${RUN_ID}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${REPO_NAME}.XXXXXX")"

cleanup() {
  local exit_code=$?
  echo "==> Cleaning up ..."
  if [ "${DELETE_REPO:-1}" -eq 1 ]; then
    curl -s -o /dev/null -X DELETE \
      -H "Authorization: token ${GITEA_TOKEN}" \
      "${GITEA_INSTANCE_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${REPO_NAME}" || true
    echo "    Deleted throwaway Gitea repo '${REPO_NAME}' (best-effort)."
  fi
  rm -rf "${WORK_DIR}"
  exit "${exit_code}"
}
trap cleanup EXIT

echo "==> Working directory: ${WORK_DIR}"
mkdir -p "${WORK_DIR}/Sources" "${WORK_DIR}/Tests/${APP_NAME}UITests"

# ---------------------------------------------------------------------------
# Minimal XcodeGen project.yml
# ---------------------------------------------------------------------------
export APP_IDENTIFIER APP_NAME
cat > "${WORK_DIR}/project.yml" <<'YAML'
name: ${APP_NAME}
options:
  bundleIdPrefix: com.local.e2e
targets:
  ${APP_NAME}:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources: [Sources]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: ${APP_IDENTIFIER}
        PRODUCT_NAME: ${APP_NAME}
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        SWIFT_VERSION: "5.0"
        TARGETED_DEVICE_FAMILY: "1,2"
        # Signing intentionally disabled: this smoke test only verifies
        # pipeline wiring, not code signing (that's exercised separately
        # via fastlane match, see infra/INFRA.md).
        CODE_SIGNING_ALLOWED: NO
        CODE_SIGNING_REQUIRED: NO
  ${APP_NAME}UITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "16.0"
    sources: [Tests/${APP_NAME}UITests]
    settings:
      base:
        CODE_SIGNING_ALLOWED: NO
        CODE_SIGNING_REQUIRED: NO
    dependencies:
      - target: ${APP_NAME}
schemes:
  ${APP_NAME}:
    build:
      targets:
        ${APP_NAME}: all
        ${APP_NAME}UITests: [test]
    test:
      targets:
        - ${APP_NAME}UITests
    run:
      config: Debug
    archive:
      config: Release
YAML
# XcodeGen substitutes ${VAR} from the process environment when it reads
# project.yml, so the exported APP_NAME/APP_IDENTIFIER above land in the
# generated project without a second templating pass here.

cat > "${WORK_DIR}/Sources/${APP_NAME}App.swift" <<EOF
import SwiftUI

@main
struct ${APP_NAME}App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF

cat > "${WORK_DIR}/Sources/ContentView.swift" <<'EOF'
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, CI!")
            .accessibilityIdentifier("helloLabel")
            .padding()
    }
}
EOF

cat > "${WORK_DIR}/Tests/${APP_NAME}UITests/${APP_NAME}UITests.swift" <<EOF
import XCTest

final class ${APP_NAME}UITests: XCTestCase {
    func testAppLaunchesAndShowsHelloLabel() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["helloLabel"].waitForExistence(timeout: 10))
    }
}
EOF

echo "==> Running xcodegen generate ..."
(cd "${WORK_DIR}" && xcodegen generate)

echo "==> Wiring up fastlane/.gitea via setup.sh ..."
export GITEA_TOKEN GITEA_ADMIN_USER GITEA_INSTANCE_URL
(
  cd "${WORK_DIR}"
  "${SETUP_SH}" \
    --bundle-id "${APP_IDENTIFIER}" \
    --scheme "${APP_NAME}" \
    --device-id "${DEVICE_ID:-}" \
    --gitea-repo-name "${REPO_NAME}"
)

echo "==> Committing and pushing ..."
(
  cd "${WORK_DIR}"
  git checkout -b main >/dev/null 2>&1 || git branch -M main
  git add -A
  git -c user.email="e2e-verify@localhost" -c user.name="e2e-verify" \
    commit -q -m "e2e verify run ${RUN_ID}"
)
COMMIT_SHA="$(git -C "${WORK_DIR}" rev-parse HEAD)"
(cd "${WORK_DIR}" && git push -q gitea main)
echo "    Pushed ${COMMIT_SHA} to gitea/main."

# ---------------------------------------------------------------------------
# Poll the commit status API. Gitea posts a commit status for each Actions
# workflow run against that commit, so this is a stable proxy for "did the
# `test` job pass" without depending on internal Actions task/run API shapes
# that vary more across Gitea versions.
# ---------------------------------------------------------------------------
echo "==> Polling for Actions result on ${COMMIT_SHA} (timeout ${POLL_TIMEOUT_SECS}s) ..."
elapsed=0
final_state=""
while [ "${elapsed}" -lt "${POLL_TIMEOUT_SECS}" ]; do
  status_json="$(curl -s \
    -H "Authorization: token ${GITEA_TOKEN}" \
    "${GITEA_INSTANCE_URL}/api/v1/repos/${GITEA_ADMIN_USER}/${REPO_NAME}/commits/${COMMIT_SHA}/status")"
  state="$(echo "${status_json}" | jq -r '.state // "unknown"')"
  echo "    [$(date +%H:%M:%S)] status: ${state}"

  case "${state}" in
    success|failure|error)
      final_state="${state}"
      break
      ;;
  esac

  sleep "${POLL_INTERVAL_SECS}"
  elapsed=$((elapsed + POLL_INTERVAL_SECS))
done

echo ""
if [ "${final_state}" = "success" ]; then
  echo "############################################"
  echo "# PASS: end-to-end pipeline verified OK.    #"
  echo "############################################"
  exit 0
elif [ -n "${final_state}" ]; then
  echo "############################################"
  echo "# FAIL: Actions run finished with '${final_state}'."
  echo "# Check: ${GITEA_INSTANCE_URL}/${GITEA_ADMIN_USER}/${REPO_NAME}/actions"
  echo "############################################"
  exit 1
else
  echo "############################################"
  echo "# FAIL: timed out after ${POLL_TIMEOUT_SECS}s waiting for a result."
  echo "# Is the runner online? ${GITEA_INSTANCE_URL}/-/admin/actions/runners"
  echo "############################################"
  exit 1
fi
