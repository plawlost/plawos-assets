#!/bin/bash

# PlawOS Setup Script (plaw_set.sh)
# Version: 1.0
# Description: Transforms Kubuntu into PlawOS with custom branding

# Set strict mode
set -euo pipefail
IFS=$'\n\t'

# Define constants
readonly SCRIPT_VERSION="1.0"
readonly ASSET_URL="https://github.com/plawlost/plawos-assets/blob/main/assets/"
readonly LOG_FILE="/var/log/plawos_setup.log"

# Function to log messages
log_message() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    log_message "ERROR: $1"
    exit 1
}

# Function to check for root privileges
check_root() {
    if [[ $EUID -ne 0 ]]; then
        handle_error "This script must be run as root"
    fi
}

# Function to download and apply PlawOS branding
apply_branding() {
    log_message "Downloading and applying PlawOS branding..."

    # Create PlawOS sound directory
    mkdir -p /usr/share/sounds/PlawOS || handle_error "Failed to create PlawOS sound directory"

    # Download assets
    wget "${ASSET_URL}plawos-logo.png" -O /tmp/plawos-logo.png || handle_error "Failed to download PlawOS logo"
    wget "${ASSET_URL}ant-dark-theme.xz" -O /tmp/ant-dark-theme.xz || handle_error "Failed to download PlawOS theme"
    wget "${ASSET_URL}plawos-sound.wav" -O /usr/share/sounds/PlawOS/plawos-sound.wav || handle_error "Failed to download PlawOS sound"

    # Install custom theme
    unxz /tmp/ant-dark-theme.xz -c | tar -xf - -C /usr/share/plasma/desktoptheme/
    lookandfeeltool -a AntDark

    # Replace boot logo
    cp /tmp/plawos-logo.png /usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.png
    update-initramfs -u

    # Replace Kubuntu branding with PlawOS
    sed -i 's/Kubuntu/PlawOS/g' /etc/os-release /usr/share/plasma/look-and-feel/org.kubuntu.*/*.desktop /etc/issue /etc/lsb-release /usr/share/applications/*.desktop /usr/share/discover/discover.ui

    log_message "PlawOS branding applied successfully"
}

# Function to customize GRUB
customize_grub() {
    log_message "Customizing GRUB..."
    sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="PlawOS"/' /etc/default/grub
    update-grub
}

# Function to clean up
cleanup() {
    log_message "Cleaning up temporary files..."
    rm -f /tmp/plawos-logo.png /tmp/ant-dark-theme.xz
}

# Main function
main() {
    log_message "Starting PlawOS setup script v${SCRIPT_VERSION}"

    check_root
    apply_branding
    customize_grub
    cleanup

    log_message "PlawOS setup completed successfully"
    echo "Setup is complete! Please reboot to enjoy your new PlawOS experience."
}

# Run the main function
main "$@"
https://github.com/plawlost/plawos-assets/blob/main/assets/
