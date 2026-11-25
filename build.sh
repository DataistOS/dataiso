#!/usr/bin/env bash
# build.sh - Dataist OS Builder
# Description: Automates ecosystem .deb packaging (transitional) and ISO generation for Dataist OS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ECOSYSTEM_SCRIPT="$SCRIPT_DIR/ecosystem-build/build-all-deb.sh"

BUILD_DEB_ECOSYSTEM="${BUILD_DEB_ECOSYSTEM:-1}"

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root."
    exit 1
fi

if [[ "$BUILD_DEB_ECOSYSTEM" == "1" ]]; then
    if [[ -x "$ECOSYSTEM_SCRIPT" ]]; then
        echo "Starting ecosystem .deb build..."
        if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
            su - "$SUDO_USER" -c "PATH=\"\$PATH\" bash '$ECOSYSTEM_SCRIPT'"
        else
            bash "$ECOSYSTEM_SCRIPT"
        fi
    else
        echo "Warning: $ECOSYSTEM_SCRIPT not found or not executable, skipping .deb build."
    fi
fi

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