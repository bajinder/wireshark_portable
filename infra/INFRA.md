# Local iOS CI — Runbook

A self-contained CI system for iOS apps that runs entirely on one Mac mini:
Gitea (git server + CI web UI + Actions) in Docker, a native macOS Gitea
Actions runner (so jobs can see Xcode and a plugged-in iPhone), fastlane for
build/sign/test/upload, and fastlane match backed by a local git repo for
certificate storage. No external CI service, no cloud cert storage.

Everything referenced here lives under this repo's `infra/` directory
(source of truth, version-controlled) and under `~/infra` on the Mac
(runtime state: logs, the runner's working directory, the match cert
store, downloaded API keys — none of that belongs in git).

---

## 1. Architecture at a glance

```
┌─────────────────────────────┐      registers as runner       ┌──────────────────────────┐
│ Docker: gitea/gitea          │◀───────────────────────────────│ act_runner (native, brew) │
│  - git server (HTTP+SSH)     │                                 │  label: macos-host:host   │
│  - web UI :3000               │──── dispatches jobs ──────────▶│  runs jobs in a real      │
│  - Gitea Actions enabled     │                                 │  shell, no container      │
└─────────────────────────────┘                                 └────────────┬─────────────┘
                                                                               │ runs
                                                                               ▼
                                                    fastlane (test / beta / release lanes)
                                                    - xcodegen generate
                                                    - scan (XCUITest on device/simulator)
                                                    - match (reads ~/infra/certs.git)
                                                    - gym (build signed .ipa)
                                                    - pilot (upload TestFlight)
                                                    - deliver (metadata only)
```

Key design points, and why:

- **Gitea in Docker, runner on bare metal.** Gitea itself doesn't need
  Xcode or hardware access, so containerizing it is free simplicity and
  easy persistence via named volumes. The runner *does* need Xcode and a
  USB-attached iPhone, neither of which a container can see on macOS —
  so it's installed with Homebrew and runs directly on the host.
- **Runner uses the `host` executor, not Docker.** Registering the runner
  with label `macos-host:host` tells act_runner to run job steps as plain
  shell commands on the Mac instead of spinning up containers. This is
  what makes `xcodebuild`/`xcrun`/`devicectl` and the physical device
  visible to CI jobs at all.
- **Certs never leave the Mac.** `fastlane match` is pointed at a local
  bare git repo (`~/infra/certs.git`) instead of a hosted git provider.
  There's no external dependency and no cert material transits the
  network.
- **App Store Connect API key auth only.** No Apple ID password or
  interactive 2FA prompt is used anywhere in the automated lanes — see
  §3.

---

## 2. Prerequisites (once, before running anything)

On the Mac mini:

- macOS with Xcode installed (the version matching your app's deployment
  target) and its license accepted: `sudo xcodebuild -license accept`.
- [Homebrew](https://brew.sh) installed.
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
  installed and running (`docker compose` must work).
- An iPhone you can plug in via USB for on-device XCUITest runs, with
  **Developer Mode enabled**: Settings → Privacy & Security → Developer
  Mode → toggle on → the phone reboots and asks you to confirm. Without
  this, Xcode/the runner cannot install or run test builds on the device.
- An Apple Developer Program membership (for match/gym/pilot/deliver to
  have anything to sign with or upload to).

---

## 3. First-time setup, in order

Run everything from the root of this repo unless noted otherwise. Steps
marked **[Mac]** must run on the Mac mini (they are macOS-only); nothing
in this repo is expected to run on a Linux authoring machine.

### 3.1 Start Gitea **[Mac]**

```sh
infra/scripts/01_start_gitea.sh
```

Brings up the container, waits for `/api/healthz`, and creates an admin
user (`admin` by default) with either the password you set via
`GITEA_ADMIN_PASSWORD` beforehand, or a randomly generated one printed
**once** to the terminal — save it immediately.

**MANUAL STEP:** Log in at http://localhost:3000 with that admin user,
then create a personal access token for API/CLI use:

> avatar (top right) → Settings → Applications → "Manage Access Tokens" →
> Generate New Token → name it (e.g. `infra-cli`) → scope: `repo` (also
> `admin:org` if you'll create repos under an org, not your user account).

Export it wherever you keep local secrets (e.g. `~/.zprofile`, sourced by
your shell — **not** by launchd, see §3.4):

```sh
export GITEA_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export GITEA_ADMIN_USER=admin
export GITEA_INSTANCE_URL=http://localhost:3000
```

### 3.2 Install runner tooling **[Mac]**

```sh
infra/scripts/02_install_runner.sh
```

Installs `act_runner`, `fastlane`, `xcodegen`, `jq` via Homebrew; creates
`~/infra/logs`, `~/infra/keys`, `~/infra/runner`; and mirrors this repo's
`infra/templates/` into `~/infra/templates/` (that's the canonical
location `infra/templates/setup.sh` expects to run from when wiring up
new app repos — see §4).

### 3.3 Generate a runner registration token **[Mac, manual]**

Either:

> Gitea web UI → Site Administration (wrench icon) → Actions → Runners →
> "Create new runner" → copy the token shown.

or from the CLI:

```sh
docker exec gitea gitea actions generate-runner-token
```

### 3.4 Register the runner + install the launchd service **[Mac]**

```sh
infra/scripts/03_register_runner.sh <token>
```

This registers act_runner with label `macos-host:host` (must match
`runs-on: macos-host` in every workflow — see §6), writes
`~/infra/runner/config.yaml`, installs
`~/Library/LaunchAgents/com.local.act-runner.plist`, and starts it via
`launchctl bootstrap`.

**Why a launchd plist and not just running `act_runner daemon` in a
terminal:** it needs to survive reboots and terminal closes unattended,
since this Mac mini runs headless/unattended CI.

**Gotcha already handled for you:** launchd agents do not inherit your
interactive shell's `PATH`, `.zprofile`, etc. The plist hardcodes an
explicit `PATH` (including `/opt/homebrew/bin` for Homebrew tools and
Xcode's CLI tool location) and `DEVELOPER_DIR`. If you install tools
somewhere non-standard, or jobs report "command not found" despite the
same command working in your terminal, this is the first thing to check
— see §8.

Verify it's online: http://localhost:3000/-/admin/actions/runners should
show it as "Idle"/"Online" with label `macos-host`.

### 3.5 Create the match certificate store **[Mac]**

```sh
infra/scripts/04_setup_match_repo.sh
```

Creates a bare git repo at `~/infra/certs.git`. This is where all
certificates and provisioning profiles fastlane match manages will live,
encrypted with your `MATCH_PASSWORD`.

**MANUAL STEP — choosing MATCH_PASSWORD:** there's nothing to "generate"
here; you pick a strong passphrase yourself the first time you actually
run `fastlane match` (e.g. during the first `fastlane beta` run for a
real app). match derives its encryption key from this passphrase and
will refuse to decrypt anything in the repo later if it doesn't match.
**Write it down somewhere durable (password manager).** There is no
recovery path — losing it means wiping `~/infra/certs.git` and
regenerating every cert/profile from the Apple Developer portal.

### 3.6 Create an App Store Connect API key **[manual, one-time per team]**

This is the credential fastlane uses instead of your Apple ID + 2FA for
match, pilot, and deliver. Exact click path:

1. Go to https://appstoreconnect.apple.com → **Users and Access**.
2. Open the **Integrations** tab → **App Store Connect API**.
3. Under **Team Keys**, click the **+ / "Generate API Key"** button.
4. Name it (e.g. `local-ci`), set **Access = App Manager** (enough to
   manage builds/TestFlight/metadata without full Admin rights).
5. **Download the `.p8` file immediately.** Apple lets you download it
   exactly once — if you navigate away without downloading, you must
   revoke the key and generate a new one.
6. Note the **Key ID** (shown in the Team Keys table) and the **Issuer
   ID** (shown above the table — one Issuer ID per team, shared by all
   keys).

Move the file into place and record the IDs:

```sh
mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/infra/keys/AuthKey_XXXXXXXXXX.p8
```

Then set, wherever you keep shell secrets:

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH="$HOME/infra/keys/AuthKey_${ASC_KEY_ID}.p8"
export MATCH_GIT_URL="file://$HOME/infra/certs.git"
export MATCH_PASSWORD='the passphrase you chose in 3.5'
```

See `infra/.env.default` for the full annotated list of every variable
this system uses, including which are per-app vs. shared.

**Where these env vars need to be visible from:** the runner's launchd
process (so CI jobs see them) *and* your interactive shell (so you can
run fastlane by hand while developing). The simplest approach for a
single-user box is to add the `export` lines to both:
- your shell profile (`~/.zprofile`), for interactive use, and
- the `EnvironmentVariables` dict in
  `~/Library/LaunchAgents/com.local.act-runner.plist`, for CI use — edit
  the installed copy (not the one in this repo) and
  `launchctl kickstart -k gui/$(id -u)/com.local.act-runner` to pick up
  changes. (The Fastfile/workflow templates also support Gitea repo
  secrets as an alternative — see the comments in
  `infra/templates/.gitea/workflows/ci.yml`.)

### 3.7 Verify everything end-to-end **[Mac]**

```sh
GITEA_TOKEN=... GITEA_ADMIN_USER=admin infra/scripts/05_verify_e2e.sh
```

Generates a throwaway hello-world iOS app, pushes it to a throwaway Gitea
repo, waits for the runner to execute the `test` lane, prints `PASS` or
`FAIL`, and deletes the throwaway repo. This lane doesn't need match/ASC
credentials (code signing is disabled in the generated project on
purpose) — it only proves the Gitea → Actions → runner → xcodegen →
fastlane → (device or simulator) wiring works. Run it any time you
suspect the plumbing, not your app, is broken.

---

## 4. Adding a new app repo

From inside the (new or existing) app repo's root directory on the Mac:

```sh
~/infra/templates/setup.sh \
  --bundle-id com.example.myapp \
  --scheme MyApp \
  --device-id <your iPhone's UDID>
```

(Omit flags to be prompted interactively instead.) This:

- copies in `fastlane/{Fastfile,Appfile,Matchfile,Gymfile}` and
  `.gitea/workflows/ci.yml`,
- writes `fastlane/.env.default` (placeholders, safe to commit) and
  `fastlane/.env` + `.env` (real per-app values, gitignored),
- adds standard entries to `.gitignore`,
- if `GITEA_TOKEN`/`GITEA_ADMIN_USER` are set in your env: creates the
  repo in Gitea via the API (skips if it already exists) and adds a
  `gitea` git remote.

It's idempotent — re-run any time to pick up template updates (Fastfile
etc. are always overwritten since they're app-agnostic; your `.env`
files are updated in place, preserving any lines you added by hand).

Push to trigger CI:

```sh
git push gitea main          # runs the "test" lane
git tag v1.0.0 && git push gitea v1.0.0   # runs the "beta" lane
```

**MANUAL STEP — first device trust:** the first time a build from this
pipeline installs onto your iPhone, iOS will show an "Untrusted
Developer" prompt. On the phone: Settings → General → VPN & Device
Management → select the developer profile → Trust. This only happens
once per signing certificate per device.

Find your device's UDID with `xcrun xctrace list devices` (or Xcode →
Window → Devices and Simulators).

---

## 5. Day-to-day operations

Start/stop Gitea:

```sh
cd infra && docker compose up -d      # start (also: infra/scripts/01_start_gitea.sh)
cd infra && docker compose down       # stop, keep data
cd infra && docker compose down -v    # stop and DELETE all Gitea data (destructive)
```

Runner service (launchd):

```sh
launchctl kickstart -k gui/$(id -u)/com.local.act-runner   # restart
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.local.act-runner.plist   # stop + unload
infra/scripts/03_register_runner.sh <new-token>             # reload (re-registers too)
```

Tail runner logs:

```sh
tail -f ~/infra/logs/act-runner.out.log ~/infra/logs/act-runner.err.log
```

Fastlane lanes (run manually from an app repo for debugging):

```sh
bundle exec fastlane test      # unit + UI tests, device or simulator fallback
bundle exec fastlane beta      # test -> match -> build -> TestFlight upload
bundle exec fastlane release   # beta -> metadata upload (STOPS before review submission)
```

---

## 6. What the lanes and workflow actually do

`infra/templates/fastlane/Fastfile`:

- **`test`** — checks whether `DEVICE_ID` is currently attached (via
  `xcrun devicectl list devices` / `xcrun xctrace list devices`); if
  present, runs `scan` (`run_tests`) against
  `platform=iOS,id=#{DEVICE_ID}`. If absent, prints a loud warning and
  falls back to an iPhone Simulator destination instead of failing the
  build outright.
- **`beta`** — runs `test`, then `match(type: "appstore", readonly:
  false)` (fetches/creates App Store distribution certs+profile from
  `MATCH_GIT_URL`), then `build_app` (gym, App Store export method), then
  `upload_to_testflight` (pilot) using the App Store Connect API key.
- **`release`** — runs `beta`, then `deliver` with `force: true`,
  `skip_binary_upload: true` (the binary already went up via pilot in
  `beta`), and **`submit_for_review: false`**. It uploads
  metadata/screenshots only and stops there **on purpose** — actually
  submitting a build for App Review is left as an explicit manual step
  (App Store Connect → your app → the build → "Submit for Review") so a
  CI push can never accidentally submit a release to Apple.

`infra/templates/.gitea/workflows/ci.yml`:

- `push` to `main` → `test` job only (`if:
  startsWith(github.ref, 'refs/heads/')`).
- `push` of a tag matching `v*` → `beta` job only (`if:
  startsWith(github.ref, 'refs/tags/v')`).
- Both jobs run on `runs-on: macos-host` (must match the runner label
  registered in §3.4) and start with `actions/checkout@v4` then
  `xcodegen generate` (this system assumes app repos use XcodeGen rather
  than committing an `.xcodeproj`).
- Gitea Actions is context/syntax-compatible with GitHub Actions,
  including the `github.*` expression context (there's no separate
  `gitea.*` context to learn).

---

## 7. Manual steps — quick checklist

Everything below requires a human; none of it can be scripted safely
(mostly because it involves Apple credentials, physical hardware, or
one-time secrets):

- [ ] Accept Xcode license on the Mac (`sudo xcodebuild -license accept`).
- [ ] Enable Developer Mode on the test iPhone (Settings → Privacy &
      Security → Developer Mode).
- [ ] Create the Gitea admin account's login (auto-created by
      `01_start_gitea.sh`, but you choose whether to keep the generated
      password or change it).
- [ ] Generate a Gitea personal access token for `GITEA_TOKEN` (§3.1).
- [ ] Generate a Gitea Actions runner registration token (§3.3) — this
      token is single-use for registration; re-registering needs a fresh
      one.
- [ ] Create the App Store Connect API key, download the `.p8` **once**,
      record Key ID + Issuer ID (§3.6).
- [ ] Choose and record the `MATCH_PASSWORD` passphrase on first real
      `fastlane match` run (§3.5).
- [ ] Trust the developer certificate on each new test device the first
      time a build installs (§4).
- [ ] Manually submit for App Review in App Store Connect after running
      the `release` lane — it deliberately stops before this step.

---

## 8. Troubleshooting

**Runner shows offline in the Gitea Actions UI**
- Check it's actually running: `launchctl print
  gui/$(id -u)/com.local.act-runner` (look for `state = running`).
- Check the logs: `~/infra/logs/act-runner.err.log`.
- Confirm `~/infra/runner/.runner` exists — if missing, registration
  never completed; re-run `infra/scripts/03_register_runner.sh` with a
  fresh token.
- Confirm the Mac hasn't gone to sleep — headless CI Macs should have
  sleep disabled (System Settings → Energy, or `sudo pmset -c sleep 0`
  for "never sleep while on power adapter").

**Job fails with "command not found" (xcodebuild / fastlane / xcodegen)**
- Almost always a launchd `PATH` problem — see the callout in §3.4.
  Confirm `/opt/homebrew/bin` (and the tool in question) is actually in
  the `EnvironmentVariables` PATH entry in the *installed* plist at
  `~/Library/LaunchAgents/com.local.act-runner.plist`, then
  `launchctl kickstart -k gui/$(id -u)/com.local.act-runner`.

**Device not found / test lane falls back to simulator unexpectedly**
- Confirm the iPhone is plugged in, unlocked, and trusts this Mac ("Trust
  This Computer?" prompt).
- Run `xcrun xctrace list devices` by hand on the Mac (as the same user
  the launchd agent runs as) and confirm the UDID matches `DEVICE_ID`
  exactly.
- USB hubs / cheap cables are a common flaky cause — prefer a direct
  connection.

**`fastlane match` fails to decrypt / "Failed to decrypt" errors**
- `MATCH_PASSWORD` doesn't match what the repo at `~/infra/certs.git` was
  encrypted with. There is no recovery — either recall the correct
  passphrase or `rm -rf ~/infra/certs.git` and re-run
  `infra/scripts/04_setup_match_repo.sh` to start clean (you'll need to
  regenerate certs/profiles from the Developer portal afterward).

**Signing failures during `build_app` (gym)**
- Confirm `match(type: "appstore", readonly: false)` actually ran (check
  job logs) and that the ASC API key has at least **App Manager** access
  — a **Developer**-only key can read but sometimes can't create new
  certs/profiles.
- Confirm `APP_IDENTIFIER` matches the bundle ID actually registered in
  the Apple Developer portal / used when the certs were created.

**Workflow doesn't trigger at all after `git push`**
- Confirm the pushed ref matches the trigger: branch must be exactly
  `main`, tags must match `v*` (e.g. `v1.0.0`, not `1.0.0`).
- Gitea Actions needs outbound internet access the first time it
  resolves `actions/checkout@v4` (it proxies actions from GitHub by
  default via `GITEA__actions__DEFAULT_ACTIONS_URL=github` in
  `docker-compose.yml`) — confirm the Mac has connectivity, or configure
  a local actions mirror if you want this fully offline-capable.

**`05_verify_e2e.sh` times out or fails**
- Check the runner is online first (most common cause).
- Set `DELETE_REPO=0` before running it to keep the throwaway Gitea repo
  around afterward for inspecting its Actions logs instead of having it
  deleted automatically.
