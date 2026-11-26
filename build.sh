#!/usr/bin/env bash
#
# Orchestrates ecosystem .deb packaging and ISO image generation for Dataist OS.
#
# Runs build-all-deb.sh (when BUILD_DEB_ECOSYSTEM=1) before invoking
# mkarchiso to build the target ISO image under work/ and out/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECOSYSTEM_SCRIPT="$SCRIPT_DIR/ecosystem-build/build-all-deb.sh"

BUILD_DEB_ECOSYSTEM="${BUILD_DEB_ECOSYSTEM:-1}"

# ISO generation via mkarchiso requires root privileges.
if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

if [[ "$BUILD_DEB_ECOSYSTEM" == "1" ]]; then
    if [[ -x "$ECOSYSTEM_SCRIPT" ]]; then
        echo "Starting ecosystem .deb build..."
        # Run as the original non-root sudo caller so user Flutter/Pub paths apply.
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            su - "$SUDO_USER" -c "PATH=\"\$PATH\" bash '$ECOSYSTEM_SCRIPT'"
        else
            bash "$ECOSYSTEM_SCRIPT"
        fi
    else
        echo "Warning: $ECOSYSTEM_SCRIPT not found or not executable, skipping .deb build."
    fi
fi

# Allow running .deb packaging on non-Arch/non-mkarchiso hosts without failing.
if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "Warning: 'mkarchiso' is not installed on this host. Skipping ISO build step."
    echo "Ecosystem .deb artifacts (if built) are available in: $SCRIPT_DIR/ecosystem-build/artifacts/deb/"
    exit 0
fi

echo "Cleaning up previous build artifacts..."
rm -rf "$SCRIPT_DIR/work/" "$SCRIPT_DIR/out/"

mkdir -p "$SCRIPT_DIR/work/" "$SCRIPT_DIR/out/"

echo "Starting Dataist build process..."
if mkarchiso -v -w "$SCRIPT_DIR/work/" -o "$SCRIPT_DIR/out/" "$SCRIPT_DIR"; then
    echo "---------------------------------------------------"
    echo "Build successful! The ISO is located in the 'out/' directory."
    echo "---------------------------------------------------"
else
    echo "---------------------------------------------------"
    echo "Error: Build failed. Please check the logs above."
    echo "---------------------------------------------------"
    exit 1
fi