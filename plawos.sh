#!/bin/bash

# PlawOS Setup Script
# Version: 1.0
# Description: Transforms Kubuntu into PlawOS with custom branding, optimizations, and a one-time welcome experience

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

# Function to update and upgrade the system
update_system() {
    log_message "Updating and upgrading the system..."
    apt update && apt upgrade -y || handle_error "Failed to update and upgrade the system"
}

# Function to install essential packages
install_packages() {
    log_message "Installing essential packages..."
    apt install -y latte-dock brave-browser zram-config flatpak snapd plymouth-theme-editor kvantum yad iio-sensor-proxy xserver-xorg-input-wacom plasma-discover-backend-flatpak plasma-discover-backend-snap preload earlyoom || handle_error "Failed to install essential packages"
}

# Function to optimize system performance
optimize_performance() {
    log_message "Optimizing system performance..."
    
    # Enable ZRAM
    systemctl enable zram-config

    # Reduce swappiness
    echo "vm.swappiness=10" | tee -a /etc/sysctl.conf
    sysctl -p

    # Enable and configure EarlyOOM for better memory management
    systemctl enable earlyoom
    sed -i 's/EARLYOOM_ARGS=.*/EARLYOOM_ARGS="-r 60 -m 5 -n -g"/g' /etc/default/earlyoom

    # Optimize I/O scheduler for SSDs
    echo 'ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"' | tee /etc/udev/rules.d/60-scheduler.rules

    # Enable CPU performance mode
    echo 'GOVERNOR="performance"' | tee /etc/default/cpufrequtils
    systemctl enable cpufrequtils

    log_message "System performance optimizations applied"
}

# Function to download and apply PlawOS branding
apply_branding() {
    log_message "Downloading and applying PlawOS branding..."

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

    # Set Brave as default browser
    xdg-settings set default-web-browser brave-browser.desktop

    # Replace Kubuntu branding with PlawOS
    sed -i 's/Kubuntu/PlawOS/g' /etc/os-release /usr/share/plasma/look-and-feel/org.kubuntu.*/*.desktop /etc/issue /etc/lsb-release /usr/share/applications/*.desktop /usr/share/discover/discover.ui

    log_message "PlawOS branding applied successfully"
}

# Function to enable tablet mode and stylus support
enable_tablet_mode() {
    log_message "Enabling tablet mode and stylus support..."
    gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false
    # Add more tablet and stylus configurations here
}

# Function to optimize KDE for speed
optimize_kde() {
    log_message "Optimizing KDE for speed..."
    kwriteconfig5 --file kwinrc --group Compositing --key OpenGLIsUnsafe true
    qdbus org.kde.KWin /KWin reconfigure
}

# Function to set up welcome screen and setup wizard
setup_welcome_wizard() {
    log_message "Setting up PlawOS Welcome and Setup Wizard..."

    cat <<EOF > /usr/local/bin/plawos-welcome.sh
#!/bin/bash
yad --title="Welcome to PlawOS" --center --borders=20 --width=400 --image="/usr/share/pixmaps/plawos-logo.png" --text="<b>Welcome to PlawOS!</b>\nLet's configure your system:\n- Set up tablet mode\n- Configure stylus support\n- Install essential apps." --button="Launch Setup:1" --button="Skip:0"
if [ \$? -eq 1 ]; then bash /usr/local/bin/plawos-setup.sh; fi

# Remove the welcome screen from autostart after it runs once
rm -f ~/.config/autostart/plawos-welcome.desktop
EOF

    cat <<EOF > /usr/local/bin/plawos-setup.sh
#!/bin/bash
yad --title="PlawOS Setup Wizard" --center --borders=20 --width=400 --image="/usr/share/pixmaps/plawos-logo.png" --text="<b>PlawOS Setup Wizard</b>\nLet's configure your system!" --form --field="Enable Tablet Mode:CHK" TRUE --field="Enable Stylus Support:CHK" TRUE --field="Install Essential Apps:CHK" TRUE --button="Start Setup:0"
TABLET_MODE=\$1
STYLUS_SUPPORT=\$2
ESSENTIAL_APPS=\$3
if [ "\$TABLET_MODE" = "TRUE" ]; then apt install iio-sensor-proxy -y; gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false; fi
if [ "\$STYLUS_SUPPORT" = "TRUE" ]; then apt install xserver-xorg-input-wacom -y; fi
if [ "\$ESSENTIAL_APPS" = "TRUE" ]; then apt install libreoffice vlc gimp -y; fi
yad --title="Setup Complete" --text="Your PlawOS setup is complete!" --width=300 --button=OK
EOF

    chmod +x /usr/local/bin/plawos-welcome.sh /usr/local/bin/plawos-setup.sh

    mkdir -p /etc/skel/.config/autostart
    cat <<EOF > /etc/skel/.config/autostart/plawos-welcome.desktop
[Desktop Entry]
Type=Application
Exec=/usr/local/bin/plawos-welcome.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=PlawOS Welcome
EOF

    log_message "Welcome screen and setup wizard configured"
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
    update_system
    install_packages
    optimize_performance
    apply_branding
    enable_tablet_mode
    optimize_kde
    setup_welcome_wizard
    customize_grub
    cleanup

    log_message "PlawOS setup completed successfully"
    echo "Setup is complete! Please reboot to enjoy your new PlawOS experience."
}

# Run the main function
main "$@"
