#!/usr/bin/env bash
# infra/scripts/04_setup_match_repo.sh
#
# Creates the local bare git repo that fastlane match uses as its
# certificate/profile storage backend. Bare + local means no external
# hosting is needed for signing material -- it never leaves this Mac.
#
# Idempotent: does nothing if the repo already exists.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "NOTE: this is normally run on the macOS CI Mac mini, continuing anyway." >&2
fi

command -v git >/dev/null 2>&1 || {
  echo "ERROR: git not found on PATH." >&2
  exit 1
}

CERTS_REPO="${HOME}/infra/certs.git"

mkdir -p "${HOME}/infra"

if [ -d "${CERTS_REPO}" ]; then
  echo "==> ${CERTS_REPO} already exists -- leaving it as-is."
else
  echo "==> Creating bare git repo at ${CERTS_REPO} ..."
  git init --bare "${CERTS_REPO}"
  echo "    Done."
fi

cat <<EOF

==> match storage repo ready: ${CERTS_REPO}

Use this as MATCH_GIT_URL in your .env files:
  MATCH_GIT_URL=file://${CERTS_REPO}

The first time you run \`fastlane match\` against this repo it will ask you
to set/confirm the match passphrase (MATCH_PASSWORD) -- pick a strong one
and record it somewhere safe (e.g. your password manager). There is no
recovery if it's lost; you'd have to wipe ${CERTS_REPO} and regenerate all
certs/profiles from scratch.

EOF
