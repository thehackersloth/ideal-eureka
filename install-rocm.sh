#!/bin/bash

# Script to install ROCm and configure for both data and display on Ubuntu 24.04 This will allow display and compute
# Includes a rollback mechanism to revert to current settings
# chmod +x install_rocm.sh
# ./install_rocm.sh
# ./install_rocm.sh --rollback
# Variables
ROLLBACK_DIR="$HOME/rocm_rollback"
LOGFILE="$HOME/rocm_install.log"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGFILE"
}

# Function to create a rollback snapshot
create_rollback_snapshot() {
    log "Creating rollback snapshot..."
    mkdir -p "$ROLLBACK_DIR"
    dpkg --get-selections > "$ROLLBACK_DIR/dpkg_selections.txt"
    cp -r /etc/apt/sources.list.d "$ROLLBACK_DIR/"
    cp /etc/apt/sources.list "$ROLLBACK_DIR/"
    cp /etc/environment "$ROLLBACK_DIR/"
    log "Rollback snapshot created in $ROLLBACK_DIR."
}

# Function to rollback to previous settings
rollback() {
    log "Initiating rollback..."
    if [ -d "$ROLLBACK_DIR" ]; then
        log "Restoring package selections..."
        sudo dpkg --clear-selections
        sudo dpkg --set-selections < "$ROLLBACK_DIR/dpkg_selections.txt"
        sudo apt-get dselect-upgrade -y

        log "Restoring APT sources..."
        sudo rm -rf /etc/apt/sources.list.d
        sudo cp -r "$ROLLBACK_DIR/sources.list.d" /etc/apt/
        sudo cp "$ROLLBACK_DIR/sources.list" /etc/apt/

        log "Restoring environment variables..."
        sudo cp "$ROLLBACK_DIR/environment" /etc/

        log "Rollback complete. Please reboot your system."
    else
        log "No rollback snapshot found. Cannot revert."
    fi
}

# Main installation function
install_rocm() {
    log "Starting ROCm installation..."

    # Step 1: Update system
    log "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Step 2: Install prerequisites
    log "Installing prerequisites..."
    sudo apt install -y linux-headers-$(uname -r) linux-modules-extra-$(uname -r) libnuma-dev

    # Step 3: Add ROCm repository
    log "Adding ROCm repository..."
    sudo mkdir -p /etc/apt/keyrings
    wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/rocm.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3.1 noble main" | sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt update

    # Step 4: Install ROCm
    log "Installing ROCm..."
    sudo apt install -y rocm rocm-dev

    # Step 5: Add user to video and render groups
    log "Adding user to video and render groups..."
    sudo usermod -a -G video $USER
    sudo usermod -a -G render $USER

    # Step 6: Configure environment variables
    log "Configuring environment variables..."
    echo 'export PATH=$PATH:/opt/rocm/bin:/opt/rocm/opencl/bin' | sudo tee /etc/profile.d/rocm.sh
    echo 'export HSA_OVERRIDE_GFX_VERSION=8.0.3' | sudo tee -a /etc/environment  # For RX580 (Polaris)
    source /etc/environment

    # Step 7: Verify installation
    log "Verifying ROCm installation..."
    /opt/rocm/bin/rocminfo
    /opt/rocm/opencl/bin/clinfo

    log "ROCm installation complete. Please reboot your system."
}

# Main script logic
if [ "$1" == "--rollback" ]; then
    rollback
else
    create_rollback_snapshot
    install_rocm
fi
