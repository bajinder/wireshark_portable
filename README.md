# Wireshark Portable AppImage for Ubuntu

A streamlined builder script to create an official Wireshark portable AppImage from source on Ubuntu/Debian systems.

## Overview

This project automates the process of building a self-contained, portable Wireshark AppImage that runs on Ubuntu/Debian without requiring system-wide installation. The generated AppImage bundles Wireshark with all necessary dependencies, making it easy to distribute and run across different Ubuntu versions.

## Features

- **Reproducible Builds**: Pins to a specific Wireshark release (`wireshark-4.4.9`)
- **Self-Contained**: All dependencies packaged into a single AppImage file
- **Headless Compatible**: Works on VMs and containers without `/dev/fuse`
- **Automated**: Single-script build process with comprehensive dependency management
- **No Root Conflicts**: Runs as a regular user; sudo is used only for necessary package installation steps

## Requirements

- **OS**: Ubuntu 20.04 (focal) or Debian-based systems
- **User**: Non-root user with sudo privileges
- **Disk Space**: ~5-10 GB for source code, build artifacts, and tools
- **Network**: Internet access to download Wireshark source and build tools
- **Git**: Required for cloning the Wireshark repository

## Installation & Usage

### Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/bajinder/wireshark_portable.git
   cd wireshark_portable
   ```

2. Run the build script:
   ```bash
   ./generate_portable.sh
   ```

3. The AppImage will be created as `Wireshark-x86_64.AppImage` in the current directory.

### Running the Portable Wireshark

Once built, you can run the portable Wireshark AppImage:

```bash
./Wireshark-x86_64.AppImage
```

Or make it executable and use it from anywhere:
```bash
chmod +x Wireshark-x86_64.AppImage
./Wireshark-x86_64.AppImage
```

## Build Process

The `generate_portable.sh` script performs the following steps:

1. **Validation**: Ensures the script runs as a non-root user and prevents concurrent builds
2. **Cleanup**: Removes previous build artifacts
3. **Source Fetch**: Clones the official Wireshark repository at the pinned tag
4. **Dependencies**: Installs all build dependencies via Wireshark's `debian-setup.sh` and additional tools (cmake, ninja, gcc, etc.)
5. **AppImage Tools**: Downloads and installs linuxdeploy and appimagetool helpers
6. **Compilation**: Configures and compiles Wireshark as a Release build
7. **Packaging**: Assembles the final AppImage using the `wireshark_appimage` target
8. **Output**: Moves the AppImage to the project root directory

## Configuration

Key build variables in `generate_portable.sh`:

| Variable | Value | Purpose |
|----------|-------|---------|
| `WS_TAG` | `wireshark-4.4.9` | Pinned Wireshark release version |
| `WS_REPO` | Official GitLab URL | Wireshark source repository |
| `TOOLS_DIR` | `/usr/local/bin` | Installation directory for AppImage tools |
| `OUTPUT` | `./Wireshark-x86_64.AppImage` | Final AppImage location |

To build a different Wireshark version, modify `WS_TAG` in the script before running.

## Troubleshooting

### Permission Denied Error
**Error**: "Permission denied" during moc/ninja compilation

**Solution**: Ensure you run the script as a **non-root user** (not with `sudo`):
```bash
./generate_portable.sh
```

### Lock File Error
**Error**: "Another build is already running"

**Solution**: Either wait for the previous build to complete, or remove the stale lock:
```bash
rm /tmp/wireshark-appimage-build.lock
```

### Missing Dependencies
**Error**: Build fails with missing package errors

**Solution**: Ensure your system is up to date:
```bash
sudo apt-get update
sudo apt-get upgrade
```

### /dev/fuse Not Available
**Issue**: Build fails in containerized/headless environments

**Solution**: The script automatically sets `APPIMAGE_EXTRACT_AND_RUN=1` to extract AppImage files instead of FUSE-mounting.

## System Requirements by Ubuntu Version

- **Ubuntu 20.04 (focal)**: Fully supported (uses Qt5)
- **Ubuntu 22.04 (jammy)**: Supported with Qt5 libraries
- **Ubuntu 24.04 (noble)**: Supported with Qt5 libraries

The script defaults to Qt5 as Qt6 packages are not available on Ubuntu 20.04.

## Disk Space Guide

- Wireshark source: ~500 MB
- Build directory: ~2-3 GB
- AppImage tools: ~500 MB
- Final AppImage: ~200-300 MB

**Total**: Plan for ~5-10 GB of available disk space.

## Performance Notes

- Initial build typically takes **30-45 minutes** depending on system specifications
- Subsequent builds (if you modify and rebuild) are significantly faster if you comment out the cleanup step

## License

This build script follows the same license as Wireshark. Wireshark is licensed under the GNU General Public License (GPL).

## Support & Contributions

For issues, feature requests, or contributions, please visit the [GitHub repository](https://github.com/bajinder/wireshark_portable).

## References

- [Official Wireshark Repository](https://gitlab.com/wireshark/wireshark)
- [AppImage Documentation](https://docs.appimage.org/)
- [linuxdeploy Project](https://github.com/linuxdeploy/linuxdeploy)
