#!/bin/bash
# File: setup.sh
# Description: Dataist system setup script.
# Note: Performs initial configuration and enables graphical display.

LOG_FILE="/var/log/dataist-setup.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting Dataist system setup..."

# 1. Enable essential services
log "Enabling NetworkManager and SDDM..."
systemctl enable NetworkManager.service
systemctl enable sddm.service

# 2. Setup user directories
log "Creating default user directories..."
mkdir -p /home/dataist/Documents /home/dataist/Pictures

# 3. Finalization
log "System configuration completed successfully."