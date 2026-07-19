#!/bin/bash
# build.sh - Dataist OS Builder
# Description: Automates the ISO generation process for Dataist OS.

# Ensure the script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

# Clean up previous build artifacts to ensure a fresh build
echo "Cleaning up previous build artifacts..."
rm -rf work/ out/

# Create necessary directories if they don't exist
mkdir -p work/ out/

# Start the Archiso build process
# -v: Verbose output
# -w: Working directory
# -o: Output directory
echo "Starting Dataist build process..."
if mkarchiso -v -w work/ -o out/ .; then
    echo "---------------------------------------------------"
    echo "Build successful! The ISO is located in the 'out/' directory."
    echo "---------------------------------------------------"
else
    echo "---------------------------------------------------"
    echo "Error: Build failed. Please check the logs above."
    echo "---------------------------------------------------"
    exit 1
fi