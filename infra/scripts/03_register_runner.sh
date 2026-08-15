#!/usr/bin/env bash
# infra/scripts/03_register_runner.sh
#
# Registers this Mac as a Gitea Actions runner using the HOST executor
# (no Docker -- jobs run directly in a shell on this machine, so they can
# see Xcode and the plugged-in iPhone), then installs and starts the
# launchd agent that keeps `act_runner daemon` running across reboots.
#
# Usage:
#   ./03_register_runner.sh <registration-token> [gitea-url]
#
# <registration-token> comes from either:
#   - Gitea web UI: Site Administration -> Actions -> Runners ->
#     "Create new runner" (copy the token shown), or
#   - CLI: docker exec gitea gitea actions generate-runner-token
#
# [gitea-url] defaults to http://localhost:3000
#
# Idempotent: re-running re-registers (act_runner overwrites its .runner
# state file) and reloads the launchd job.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: this script must run on macOS (the CI Mac mini), not here." >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <registration-token> [gitea-url]" >&2
  exit 1
fi

TOKEN="$1"
GITEA_URL="${2:-http://localhost:3000}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname -s)-macos-host}"
RUNNER_LABEL="macos-host:host" # host executor, no docker -- keep in sync with ci.yml `runs-on:`

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_INFRA_DIR="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
RUNNER_HOME="${HOME}/infra/runner"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENTS_DIR}/com.local.act-runner.plist"

command -v act_runner >/dev/null 2>&1 || {
  echo "ERROR: act_runner not found on PATH. Run infra/scripts/02_install_runner.sh first." >&2
  exit 1
}

mkdir -p "${RUNNER_HOME}" "${HOME}/infra/logs" "${LAUNCH_AGENTS_DIR}"

echo "==> Ensuring act_runner config exists at ${RUNNER_HOME}/config.yaml ..."
if [ ! -f "${RUNNER_HOME}/config.yaml" ]; then
  sed "s|__HOME__|${HOME}|g" "${REPO_INFRA_DIR}/templates/act-runner/config.yaml" \
    > "${RUNNER_HOME}/config.yaml"
  echo "    Wrote ${RUNNER_HOME}/config.yaml from template."
else
  echo "    ${RUNNER_HOME}/config.yaml already exists -- leaving it as-is."
fi

echo "==> Registering runner '${RUNNER_NAME}' with label '${RUNNER_LABEL}' against ${GITEA_URL} ..."
(
  cd "${RUNNER_HOME}"
  act_runner register \
    --no-interactive \
    --instance "${GITEA_URL}" \
    --token "${TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABEL}"
)
echo "    Registered. State file: ${RUNNER_HOME}/.runner"

echo "==> Installing launchd agent ..."
sed "s|__HOME__|${HOME}|g" "${REPO_INFRA_DIR}/launchd/com.local.act-runner.plist" \
  > "${PLIST_DEST}"
echo "    Wrote ${PLIST_DEST}"

# Unload any previous instance before (re)loading, ignoring errors if it
# wasn't loaded yet (fresh install).
UID_NUM="$(id -u)"
launchctl bootout "gui/${UID_NUM}" "${PLIST_DEST}" 2>/dev/null || true
launchctl bootstrap "gui/${UID_NUM}" "${PLIST_DEST}"
launchctl enable "gui/${UID_NUM}/com.local.act-runner"
launchctl kickstart -k "gui/${UID_NUM}/com.local.act-runner"

echo "==> Runner service (re)started via launchd."
sleep 2
launchctl print "gui/${UID_NUM}/com.local.act-runner" | grep -E "state|pid" || true

cat <<EOF

==> Done. The runner should now show as "Online" under:
    ${GITEA_URL}/-/admin/actions/runners

Logs:
  ${HOME}/infra/logs/act-runner.out.log
  ${HOME}/infra/logs/act-runner.err.log

Manage the service:
  launchctl kickstart -k gui/${UID_NUM}/com.local.act-runner   # restart
  launchctl bootout gui/${UID_NUM} ${PLIST_DEST}                # stop + unload

EOF
