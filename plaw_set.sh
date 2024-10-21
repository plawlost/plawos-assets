#!/bin/bash

# PlawOS Setup Script (plaw_set.sh)
# Version: 1.3
# Description: Transforms Kubuntu into PlawOS with custom branding

# Set strict mode
set -euo pipefail
IFS=$'\n\t'

# Define constants
readonly SCRIPT_VERSION="1.3"
readonly ASSET_URL="https://raw.githubusercontent.com/plawlost/plawos-assets/main/assets/"
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

# Function to safely replace text in files
safe_replace() {
    local file=$1
    local search=$2
    local replace=$3
    if [ -f "$file" ]; then
        sed -i "s/$search/$replace/g" "$file"
        log_message "Updated $file"
    else
        log_message "Warning: $file not found, skipping"
    fi
}

# Function to download and apply PlawOS branding
apply_branding() {
    log_message "Downloading and applying PlawOS branding..."

    # Download logo
    wget "${ASSET_URL}plawos-logo.png" -O /tmp/plawos-logo.png || handle_error "Failed to download PlawOS logo"

    # Replace boot logo
    cp /tmp/plawos-logo.png /usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.png
    update-initramfs -u

    # Replace Kubuntu branding with PlawOS
    safe_replace "/etc/os-release" "Kubuntu" "PlawOS"
    safe_replace "/etc/issue" "Kubuntu" "PlawOS"
    safe_replace "/etc/lsb-release" "Kubuntu" "PlawOS"

    # Update desktop files
    find /usr/share/applications -type f -name "*.desktop" -exec sed -i 's/Kubuntu/PlawOS/g' {} +

    # Update look-and-feel files (using find to avoid language-specific paths)
    find /usr/share/plasma/look-and-feel -type f -name "*.desktop" -exec sed -i 's/Kubuntu/PlawOS/g' {} +

    log_message "PlawOS branding applied successfully"
}

# Function to customize GRUB
customize_grub() {
    log_message "Customizing GRUB..."
    safe_replace "/etc/default/grub" 'GRUB_DISTRIBUTOR=.*' 'GRUB_DISTRIBUTOR="PlawOS"'
    update-grub
}

# Function to clean up
cleanup() {
    log_message "Cleaning up temporary files..."
    rm -f /tmp/plawos-logo.png
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
