#!/usr/bin/env bash
# infra/scripts/01_start_gitea.sh
#
# Starts (or restarts) the local Gitea container via docker compose, waits
# for it to become healthy, and creates the first admin user non-interactively
# (idempotent -- safe to re-run).
#
# Usage:
#   ./01_start_gitea.sh
#
# Optional env overrides:
#   GITEA_ADMIN_USER      default: admin
#   GITEA_ADMIN_PASSWORD  default: randomly generated and printed once
#   GITEA_ADMIN_EMAIL     default: admin@localhost
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_INFRA_DIR="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"

GITEA_URL="http://localhost:3000"
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-admin}"
GITEA_ADMIN_EMAIL="${GITEA_ADMIN_EMAIL:-admin@localhost}"

command -v docker >/dev/null 2>&1 || {
  echo "ERROR: docker is not installed / not on PATH. Install Docker Desktop first." >&2
  exit 1
}

echo "==> Starting Gitea via docker compose (${REPO_INFRA_DIR}/docker-compose.yml)"
(cd "${REPO_INFRA_DIR}" && docker compose up -d)

echo "==> Waiting for Gitea to become healthy at ${GITEA_URL} ..."
attempts=0
max_attempts=60 # ~5 minutes at 5s intervals
until curl --silent --fail --output /dev/null "${GITEA_URL}/api/healthz"; do
  attempts=$((attempts + 1))
  if [ "${attempts}" -ge "${max_attempts}" ]; then
    echo "ERROR: Gitea did not become healthy after $((max_attempts * 5))s." >&2
    echo "       Check logs with: docker compose -f ${REPO_INFRA_DIR}/docker-compose.yml logs gitea" >&2
    exit 1
  fi
  sleep 5
done
echo "==> Gitea is up."

echo "==> Ensuring admin user '${GITEA_ADMIN_USER}' exists (idempotent) ..."
if docker exec gitea gitea admin user list 2>/dev/null | awk '{print $2}' | grep -qx "${GITEA_ADMIN_USER}"; then
  echo "    Admin user '${GITEA_ADMIN_USER}' already exists -- skipping creation."
else
  if [ -z "${GITEA_ADMIN_PASSWORD:-}" ]; then
    GITEA_ADMIN_PASSWORD="$(openssl rand -base64 18 | tr -d '=+/' | cut -c1-20)"
    GENERATED_PASSWORD=1
  else
    GENERATED_PASSWORD=0
  fi
  docker exec gitea gitea admin user create \
    --username "${GITEA_ADMIN_USER}" \
    --password "${GITEA_ADMIN_PASSWORD}" \
    --email "${GITEA_ADMIN_EMAIL}" \
    --admin \
    --must-change-password=false
  echo "    Created admin user '${GITEA_ADMIN_USER}'."
  if [ "${GENERATED_PASSWORD}" -eq 1 ]; then
    echo ""
    echo "    ################################################################"
    echo "    # SAVE THIS PASSWORD NOW -- it will not be shown again:"
    echo "    #   user:     ${GITEA_ADMIN_USER}"
    echo "    #   password: ${GITEA_ADMIN_PASSWORD}"
    echo "    ################################################################"
    echo ""
  fi
fi

cat <<EOF

==> Gitea is running: ${GITEA_URL}
==> SSH git access:    ssh://git@localhost:2222/<owner>/<repo>.git

Next manual steps (see infra/INFRA.md for details):
  1. Log in at ${GITEA_URL} with the admin user above.
  2. Create a personal access token for API/CLI use:
     avatar (top right) -> Settings -> Applications -> Generate New Token
     (scope: repo). Put it in GITEA_TOKEN in your shell env / .env.
  3. Generate an Actions runner registration token:
     Site Administration -> Actions -> Runners -> Create new runner
     (or: docker exec gitea gitea actions generate-runner-token)
  4. Run infra/scripts/02_install_runner.sh then
     infra/scripts/03_register_runner.sh <token> on this Mac.

EOF
