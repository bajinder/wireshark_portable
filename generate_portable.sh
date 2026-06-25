#!/usr/bin/env bash
# Build an official Wireshark portable AppImage from source on Ubuntu/Debian.
# Exit on error, on unset variables, and on any failure in a pipeline.
set -euo pipefail

# ---- Guard rails ---------------------------------------------------------
# Do NOT run as root. The build must run as a normal user; only the apt and
# tool-install steps use sudo internally. Running the whole script as root (e.g.
# "sudo ./setup.sh") creates a root-owned source tree that later breaks the
# build (moc/ninja "Permission denied") and collides with non-root runs.
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script as root or with sudo." >&2
    echo "       Run it as a normal user:  ./setup.sh" >&2
    echo "       It will invoke sudo itself only for the apt/install steps." >&2
    exit 1
fi

# Prevent concurrent runs from clobbering each other's source tree.
LOCK_FILE="/tmp/wireshark-appimage-build.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "ERROR: Another build is already running (lock: $LOCK_FILE)." >&2
    echo "       Wait for it to finish, or remove the lock if it is stale." >&2
    exit 1
fi

# ---- Configuration -------------------------------------------------------
WS_TAG="wireshark-4.4.9"                       # pinned, reproducible release
WS_REPO="https://gitlab.com/wireshark/wireshark.git"   # official source repo
SRC_DIR="wireshark-source"
TOOLS_DIR="/usr/local/bin"
OUTPUT="$PWD/Wireshark-x86_64.AppImage"        # captured before any 'cd'

# AppImage helper tools that Wireshark's CMake searches for at configure time.
LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_QT_URL="https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"

# Run AppImage helper tools by self-extracting instead of FUSE-mounting, so the
# build works on headless VMs / containers without /dev/fuse.
export APPIMAGE_EXTRACT_AND_RUN=1
export DEBIAN_FRONTEND=noninteractive

echo "========================================================="
echo " Official Wireshark Portable AppImage Builder ($WS_TAG)"
echo "========================================================="

echo "[1/5] Cleaning previous build artifacts..."
rm -rf "$SRC_DIR"

echo "[2/5] Fetching Wireshark source ($WS_TAG)..."
git clone --depth 1 --branch "$WS_TAG" "$WS_REPO" "$SRC_DIR"

echo "[3/5] Installing build dependencies via Wireshark's debian-setup.sh..."
sudo apt-get update
# debian-setup.sh installs the exact required deps (glib, gcrypt, c-ares, pcre2,
# speexdsp, pcap, Qt5, ...). Extra unknown args (-y) are forwarded to apt-get.
# Ubuntu 20.04 (focal) does not ship Qt6 packages; use Qt5 instead.
sudo DEBIAN_FRONTEND=noninteractive "$SRC_DIR/tools/debian-setup.sh" --install-qt5-deps -y
# Tools needed to compile and to assemble the AppImage.
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git cmake ninja-build gcc g++ bison flex curl file libfuse2

echo "[3b/5] Installing AppImage helper tools to $TOOLS_DIR..."
download_tool() {
    local url="$1" dest="$2"
    # -f makes curl fail on HTTP errors instead of saving an error page.
    sudo curl -fL --retry 3 -o "$dest" "$url"
    sudo chmod 755 "$dest"
    if ! file "$dest" | grep -qiE "ELF|executable"; then
        echo "ERROR: $dest is not an executable (download failed)." >&2
        exit 1
    fi
}
download_tool "$LINUXDEPLOY_URL"    "$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
download_tool "$LINUXDEPLOY_QT_URL" "$TOOLS_DIR/linuxdeploy-plugin-qt-x86_64.AppImage"
download_tool "$APPIMAGETOOL_URL"   "$TOOLS_DIR/appimagetool-x86_64.AppImage"

echo "[4/5] Configuring build and compiling..."
cd "$SRC_DIR"
rm -rf build && mkdir build && cd build

# Help linuxdeploy-plugin-qt locate Qt5 (Qt6 is not available on Ubuntu 20.04).
QMAKE="$(command -v qmake || true)"
export QMAKE

# The wireshark_appimage target REQUIRES a Release build installed under /usr.
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DUSE_qt6=OFF ..

echo "--> Compiling Wireshark (this can take a while)..."
ninja
echo "--> Assembling the AppImage..."
ninja wireshark_appimage

echo "[5/5] Collecting the AppImage..."
APPIMAGE_FILE="$(find . -maxdepth 1 -name 'Wireshark*.AppImage' | head -n 1)"

if [ -n "$APPIMAGE_FILE" ] && [ -f "$APPIMAGE_FILE" ]; then
    mv "$APPIMAGE_FILE" "$OUTPUT"
    chmod +x "$OUTPUT"
    echo "========================================================="
    echo " SUCCESS! Your portable standalone file has been created."
    echo " Final Location: $OUTPUT"
    echo "========================================================="
else
    echo "Error: Could not find the generated AppImage in $(pwd)." >&2
    exit 1
fi
