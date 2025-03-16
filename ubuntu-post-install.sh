#!/bin/bash

: '
Ubuntu Post-Installation Script

This script was originally developed on Ubuntu 23.10 (Mantic Minotaur),
and has also been tested and runs smoothly on Ubuntu 24.04 (Noble Numbat).
While it may work on other Ubuntu versions or derivatives,
full compatibility is only guaranteed on Ubuntu 23.10.

Author : Franck FERMAN
Date   : 06/12/2023
Version: 1.0.0
'


# ----------------------------------------------
# Root Privilege Verification
# ----------------------------------------------
require_admin_rights() {
    : '
    Ensure that the user has administrative (root) privileges for the entire script execution.

    Description:
        - Prompt for sudo password if not already active.
        - Exit immediately if sudo rights are unavailable.
        - Keep the sudo session alive during the whole script execution using a background process.

    Args:
        None

    Returns:
        Exits the script with code 1 if sudo privileges are unavailable.
        No explicit return value (implicit 0) if sudo access is granted and background refresh process starts successfully.
    '

    # ---[ Step 1: Initial sudo access check ]---
    # Prompt for sudo access. Exit if user cannot elevate privileges.
    if ! sudo -v; then
        echo "❌ This script requires administrative privileges. Please run it as a user with sudo rights."
        exit 1
    fi

    # ---[ Step 2: Keep sudo session alive in background ]---
    # Launch a background loop to refresh sudo timestamp every 60 seconds.
    # This prevents sudo from timing out during long script execution.
    # The loop will terminate when the main script process ends.
    while true; do
        sudo -n true      # Refresh sudo timestamp without prompting for password
        sleep 60          # Wait before refreshing again
        kill -0 "$$" || exit  # If main script is no longer running, exit this loop
    done 2>/dev/null &   # Run loop silently in background
}


# ----------------------------------------------
# Initial Banner Display
# ----------------------------------------------
show_banner() {
    : '
    Display a banner for the post-installation script.

    Description:
        Prints an ASCII art header to introduce the script when executed.
        Used for aesthetic and informational purposes at the start of execution.

    Args:
        None

    Returns:
        None
    '

    # ---[ Display ASCII art banner ]---
    # Decorative header to indicate script start.
    cat << "EOF"
     ,-O
    O(_)) Ubuntu post-install script
     `-O
EOF
}


# ----------------------------------------------
# Internet Connectivity Check
# ----------------------------------------------
check_internet_connectivity() {
    : '
    Check internet connectivity by pinging a specified host (default: 1.1.1.1).

    Description:
        Pings a given IP address or domain name to verify that the system
        has an active internet connection.
        By default, it uses Cloudflare DNS (1.1.1.1) if no host is provided.

    Args:
        $1 (string, optional): IP address or domain to ping. Defaults to 1.1.1.1.

    Returns:
        0 if the host is reachable (successful ping).
        1 if the host is unreachable (ping failed).
    '

    # ---[ Define host to ping, defaulting to 1.1.1.1 ]---
    local host="${1:-1.1.1.1}"

    # ---[ Perform ping test ]---
    # -c 2 : Send 2 ICMP packets.
    # -W 5 : Wait up to 5 seconds for a response (per packet).
    # Redirect output to /dev/null for silent operation.
    ping -c 2 -W 5 "$host" > /dev/null 2>&1

    # ---[ Return ping command exit status ]---
    # Return 0 if successful, 1 otherwise.
    return $?
}


# ----------------------------------------------
# System Update
# ----------------------------------------------
perform_system_update() {
    : '
    Perform a full system update if internet connectivity is available.

    Description:
        - Verifies internet connectivity using check_internet_connectivity().
        - If connected, updates package lists, upgrades packages, and removes unnecessary packages.
        - If no internet is detected, skips the update process gracefully.

    Args:
        None

    Returns:
        None (continues script execution regardless of update outcome).
    '

    echo "-----------------------------"
    echo "[*] System update process initiated."
    echo "-----------------------------"

    # ---[ Step 1: Check internet connectivity before updating ]---
    if check_internet_connectivity; then
        echo -e "\n[+] Internet connectivity confirmed. Proceeding with system updates..."

        # ---[ Step 2: Update package lists ]---
        echo -e "\n[+] Updating package lists (apt update)..."
        sudo apt update

        # ---[ Step 3: Upgrade all packages ]---
        echo -e "\n[+] Upgrading all packages (apt full-upgrade)..."
        sudo apt full-upgrade -y

        # ---[ Step 4: Clean up partial and unnecessary files ]---
        echo -e "\n[+] Cleaning up package cache (apt autoclean)..."
        sudo apt autoclean -y  # Remove retrieved package files no longer needed

        # ---[ Step 5: Remove unused packages and dependencies ]---
        echo -e "\n[+] Removing unused packages (apt autoremove)..."
        sudo apt autoremove -y  # Remove packages installed as dependencies but no longer needed

        echo -e "\n✅ System update process completed successfully."
    else
        echo -e "\n⚠️ Skipping system update: No internet connection detected."
    fi

    echo "-----------------------------"
}


# ----------------------------------------------
# UFW Configuration
# ----------------------------------------------
configure_ufw() {
    : '
    Configure Uncomplicated Firewall (UFW) settings.

    Description:
        - Enables UFW if it is not already active.
        - Sets default firewall rules: deny all incoming traffic, allow all outgoing traffic.
        - Ensures a basic secure firewall setup.

    Args:
        None

    Returns:
        None (exits with script continuation).
    '

    echo "-----------------------------"
    echo "[*] UFW configuration process initiated."
    echo "-----------------------------"

    # ---[ Step 1: Ensure UFW is active ]---
    if ! sudo ufw status | grep -q "^Status: active"; then
        echo "[+] UFW is inactive. Enabling..."
        sudo ufw --force enable  # --force prevents confirmation prompt
    else
        echo "[=] UFW is already active."
    fi

    # ---[ Step 2: Apply default firewall policies ]---
    echo "[+] Setting up default UFW rules..."

    sudo ufw default deny incoming  # Block all incoming traffic by default
    sudo ufw default allow outgoing  # Allow outgoing traffic by default

    # ---[ Step 3: Display UFW status summary ]---
    echo "[*] UFW configuration completed successfully."
    echo "[=] Current UFW status:"
    sudo ufw status verbose  # Show active rules and status

    echo "-----------------------------"
}


# ----------------------------------------------
# GSettings Update Utility
# ----------------------------------------------
set_gsetting() {
    : '
    Update a gsettings key with a new value if different from the current value.

    Description:
        - Retrieves the current value of the specified gsettings key.
        - If the value differs from the provided value, update it.
        - Supports both string and numeric values.

    Args:
        key (str): The gsettings key to set.
        value (str): The value to assign to the key.

    Returns:
        None
    '

    local key=$1
    local value=$2
    local current_value

    echo -e "\n[*] Processing gsetting for key: $key"

    # ---[ Step 1: Get the current value of the gsettings key ]---
    current_value=$(gsettings get $key 2> /dev/null)

    # ---[ Step 2: Check if the key exists ]---
    if [ $? -ne 0 ]; then
        echo "[!] The key $key does not exist."
        return
    fi

    # ---[ Step 3: Update the key if necessary ]---
    if [ "$current_value" != "$value" ]; then
        echo "[+] Setting $key to $value."

        # Handle numeric values without quotes, otherwise quote strings
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            gsettings set $key $value
        else
            gsettings set $key "$value"
        fi
    else
        echo "[=] $key is already set to $value."
    fi
}


# ----------------------------------------------
# GNOME Theme Configuration
# ----------------------------------------------
configure_theme() {
    : '
    Configure the GNOME desktop environment theme and background.

    Description:
        - Apply a dark color scheme preference.
        - Search for available GTK themes and apply a preferred theme ("Yaru-red-dark"),
          with a fallback to "Adwaita-dark" if available.
        - Set the desktop background color to solid black, adjusting primary and secondary
          colors if writable.
        - Clear background images to ensure a plain black desktop if supported.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting GNOME theme configuration."
    echo "-----------------------------"

    # ---[ Step 1: Apply dark color scheme preference ]---
    echo "[+] Applying dark color scheme..."
    set_gsetting "org.gnome.desktop.interface color-scheme" "'prefer-dark'"

    # ---[ Step 2: Search and apply available GTK themes ]---
    echo "[*] Searching for available GTK themes..."
    themes=$(ls -d /usr/share/themes/* 2>/dev/null | xargs -L 1 basename)

    if [ -z "$themes" ]; then
        echo "[!] No additional themes found. Skipping theme setup."
    else
        if echo "$themes" | grep -q "Yaru-red-dark"; then
            echo "[+] 'Yaru-red-dark' theme found. Applying it."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Yaru-red-dark'"
        elif echo "$themes" | grep -q "Adwaita-dark"; then
            echo "[+] 'Yaru-red-dark' not found. Applying fallback 'Adwaita-dark' theme."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Adwaita-dark'"
        else
            echo "[!] No suitable dark theme found. Theme remains unchanged."
        fi
    fi

    # ---[ Step 3: Set solid black as desktop background ]---
    echo "[*] Setting solid black as desktop background..."

    # Set primary and secondary colors to black if writable
    for key in primary-color secondary-color; do
        if gsettings writable org.gnome.desktop.background "$key" > /dev/null 2>&1; then
            echo "[+] Setting $key to black."
            set_gsetting "org.gnome.desktop.background.$key" "#000000"
        else
            echo "[!] Cannot write to $key. Skipping."
        fi
    done

    # Clear picture-uri and picture-uri-dark to ensure no background image
    for key in picture-uri picture-uri-dark; do
        if gsettings writable org.gnome.desktop.background "$key" > /dev/null 2>&1; then
            echo "[+] Clearing $key (no background image)."
            set_gsetting "org.gnome.desktop.background.$key" "''"
        else
            echo "[!] Cannot write to $key. Skipping."
        fi
    done

    echo "[*] GNOME theme configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GNOME Ubuntu Desktop Configuration
# ----------------------------------------------
configure_ubuntu_desktop() {
    : '
    Configure the Ubuntu GNOME desktop environment (Dock, icons placement, etc.).

    Description:
        - Set new icons to appear in the top-left corner.
        - Adjust Dash to Dock settings: disable panel mode and set icon size.
        - Provides a consistent desktop appearance optimized for usability.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Ubuntu desktop configuration."
    echo "-----------------------------"

    # ---[ Step 1: Set new icons placement ]---
    echo "[+] Setting new icons to appear at the top-left corner."
    set_gsetting "org.gnome.shell.extensions.ding start-corner" "'top-left'"

    # ---[ Step 2: Disable panel mode (Dash to Dock) ]---
    echo "[+] Disabling panel mode (Dash to Dock)."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock extend-height" false

    # ---[ Step 3: Set Dash to Dock icon size ]---
    echo "[+] Setting Dash to Dock icon size to 42."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock dash-max-icon-size" 42

    echo "[*] Ubuntu desktop configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Privacy Settings Configuration
# ----------------------------------------------
configure_privacy_settings() {
    : '
    Configure privacy and security-related settings for GNOME on Ubuntu.

    Description:
        - Disable unnecessary connectivity checks and location services.
        - Configure screen lock and session timeout for security.
        - Set privacy-related preferences for files, trash, and temporary files.
        - Disable technical reporting, identity exposure, and usage statistics.
        - Disable remote desktop services (RDP, VNC).
        - Prevent storing of application usage data.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting privacy configuration."
    echo "-----------------------------"

    # ---[ Step 1: Disable connectivity checking ]---
    echo "[+] Disabling connectivity checking."
    busctl --system set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled "b" 0

    # ---[ Step 2: Configure screen lock and session idle settings ]---
    echo "[+] Configuring screen lock settings."
    set_gsetting "org.gnome.desktop.screensaver lock-enabled" true
    set_gsetting "org.gnome.desktop.screensaver lock-delay" "uint32 0"
    set_gsetting "org.gnome.desktop.screensaver idle-activation-enabled" true
    set_gsetting "org.gnome.desktop.session idle-delay" "uint32 300"

    # ---[ Step 3: Disable location services ]---
    echo "[+] Disabling location services."
    set_gsetting "org.gnome.system.location enabled" false

    # ---[ Step 4: Configure file history and recent files settings ]---
    echo "[+] Configuring file history settings."
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" true
    set_gsetting "org.gnome.desktop.privacy recent-files-max-age" 1
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" false  # Final state: disabled, minimal retention set before

    # ---[ Step 5: Enable automatic cleanup of old files ]---
    echo "[+] Enabling automatic removal of old trash and temporary files."
    set_gsetting "org.gnome.desktop.privacy remove-old-trash-files" true
    set_gsetting "org.gnome.desktop.privacy remove-old-temp-files" true

    echo "[+] Setting old files age to 0 (immediate cleanup)."
    set_gsetting "org.gnome.desktop.privacy old-files-age" "uint32 0"

    # ---[ Step 6: Disable technical reports and usage stats ]---
    echo "[+] Disabling technical problem reports."
    set_gsetting "org.gnome.desktop.privacy report-technical-problems" false

    echo "[+] Disabling software usage statistics."
    set_gsetting "org.gnome.desktop.privacy send-software-usage-stats" false

    # ---[ Step 7: Hide user identity ]---
    echo "[+] Hiding user identity."
    set_gsetting "org.gnome.desktop.privacy hide-identity" true

    # ---[ Step 8: Disable remote desktop services ]---
    echo "[+] Disabling remote desktop services (RDP and VNC)."
    set_gsetting "org.gnome.desktop.remote-desktop.rdp enable" false
    set_gsetting "org.gnome.desktop.remote-desktop.vnc enable" false

    # ---[ Step 9: Prevent remembering app usage ]---
    echo "[+] Disabling remembering app usage."
    set_gsetting "org.gnome.desktop.privacy remember-app-usage" false

    echo "[*] Privacy configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Sound Settings Configuration
# ----------------------------------------------
configure_sound_settings() {
    : '
    Mute system output and disable microphone input for privacy.

    Description:
        - Mutes the Master audio output to ensure no sound is played.
        - Disables microphone input (Capture) to avoid unintended recording.
        - Applies system-wide audio privacy settings using amixer.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting sound configuration."
    echo "-----------------------------"

    # ---[ Step 1: Mute system output ]---
    echo "[+] Muting system output (Master)."
    amixer set Master mute

    # ---[ Step 2: Disable microphone input ]---
    echo "[+] Disabling microphone input (Capture)."
    amixer set Capture nocap

    echo "[*] Sound configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Power & Performance Settings Configuration
# ----------------------------------------------
configure_power_perfs_settings() {
    : '
    Configure power and performance settings, including timeouts and profiles.

    Description:
        - Set GNOME power profile to "performance" mode.
        - Enable screen dimming and power saver on low battery.
        - Adjust suspend and inactivity timeouts for both AC and battery.
        - Temporarily set suspend modes to configure timeouts properly,
          then restore them to "nothing" to disable automatic suspend.
        - Set logout delay for inactive sessions.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting power and performance configuration."
    echo "-----------------------------"

    # ---[ Step 1: Set performance power profile ]---
    echo "[+] Setting power profile to performance."
    set_gsetting "org.gnome.shell last-selected-power-profile" "'performance'"

    # ---[ Step 2: Enable screen dimming and battery saver ]---
    echo "[+] Enabling screen dimming."
    set_gsetting "org.gnome.settings-daemon.plugins.power idle-dim" true

    echo "[+] Enabling automatic power saver on low battery."
    set_gsetting "org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery" true

    # ---[ Step 3: Temporarily set suspend mode to adjust timeouts ]---
    echo "[+] Temporarily enabling suspend to adjust timeout settings."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'suspend'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'suspend'"

    # ---[ Step 4: Set logout delay and sleep timeouts ]---
    echo "[+] Setting logout delay to 2 hours."
    set_gsetting "org.gnome.desktop.screensaver logout-delay" "uint32 7200"

    echo "[+] Setting sleep inactive timeout to 2 hours (AC and battery)."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout" 7200
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout" 7200

    # ---[ Step 5: Disable suspend after timeout configuration ]---
    echo "[+] Disabling suspend after timeout configuration."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'nothing'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'nothing'"

    echo "[*] Power and performance configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Display & Interface Settings Configuration
# ----------------------------------------------
configure_display_settings() {
    : '
    Configure display and interface settings, including battery percentage and Night Light mode.

    Description:
        - Enable battery percentage display in the system tray.
        - Activate Night Light mode to reduce blue light automatically from sunset to sunrise.
        - Set Night Light color temperature for eye comfort.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting display and interface configuration."
    echo "-----------------------------"

    # ---[ Step 1: Enable battery percentage display ]---
    echo "[+] Enabling battery percentage display."
    set_gsetting "org.gnome.desktop.interface show-battery-percentage" true

    # ---[ Step 2: Enable and configure Night Light ]---
    echo "[+] Enabling Night Light (automatic from sunset to sunrise)."
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-enabled" true
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-schedule-automatic" true

    echo "[+] Setting Night Light temperature to 2700K."
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-temperature" "uint32 2700"

    echo "[*] Display and interface configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Keyboard Layout Settings Configuration
# ----------------------------------------------
configure_keyboard_settings() {
    : '
    Configure keyboard layout: Add French (AZERTY) if not already present.

    Description:
        - Check if the French (AZERTY) keyboard layout is already configured.
        - If not present, add French (AZERTY) and US layouts to the system input sources.
        - Ensures the user can switch between US and FR (AZERTY) layouts.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting keyboard layout configuration."
    echo "-----------------------------"

    # ---[ Step 1: Retrieve current input sources ]---
    local current_sources
    current_sources=$(gsettings get org.gnome.desktop.input-sources sources)

    # ---[ Step 2: Check if French (AZERTY) layout is already present ]---
    if echo "$current_sources" | grep -q "('xkb', 'fr+azerty')"; then
        echo "[=] French (AZERTY) keyboard layout is already present."
    else
        # ---[ Step 3: Add French (AZERTY) and US layouts ]---
        echo "[+] Adding French (AZERTY) and US keyboard layouts."
        set_gsetting "org.gnome.desktop.input-sources mru-sources" "[('xkb', 'fr+azerty'), ('xkb', 'us')]"
        set_gsetting "org.gnome.desktop.input-sources sources" "[('xkb', 'us'), ('xkb', 'fr+azerty')]"
    fi

    echo "[*] Keyboard layout configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Calendar & Clock Settings Configuration
# ----------------------------------------------
configure_calendar_clock_settings() {
    : '
    Configure GNOME calendar and clock settings.

    Description:
        - Show weekday and date in the top bar clock.
        - Enable week numbers display in the GNOME calendar.
        - Improve time and date visibility for better usability.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting calendar and clock settings configuration."
    echo "-----------------------------"

    # ---[ Step 1: Enable weekday and date display in clock ]---
    echo "[+] Enabling weekday display in clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-weekday" true

    echo "[+] Enabling date display in clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-date" true

    # ---[ Step 2: Enable week numbers in calendar ]---
    echo "[+] Enabling week numbers in calendar..."
    set_gsetting "org.gnome.desktop.calendar show-weekdate" true

    echo "[*] Calendar and clock settings configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# File Manager (Nautilus) Settings Configuration
# ----------------------------------------------
configure_file_manager_settings() {
    : '
    Configure GNOME Nautilus and FileChooser preferences.

    Description:
        - Sort directories first in file chooser dialogs.
        - Enable tree view in Nautilus list mode.
        - Show "Create Link" and "Delete Permanently" in context menus.
        - Enable recursive search, image thumbnails, and item counts.
        - Configure grid view captions (type, size, permissions).
        - Display hidden files everywhere (Nautilus and file chooser).

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting file manager preferences configuration."
    echo "-----------------------------"

    # ---[ Step 1: Sorting and FileChooser preferences ]---
    echo "[+] Sorting directories first in file chooser..."
    set_gsetting "org.gtk.Settings.FileChooser sort-directories-first" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser sort-directories-first" true

    # ---[ Step 2: Nautilus list view options ]---
    echo "[+] Enabling tree view in list mode..."
    set_gsetting "org.gnome.nautilus.list-view use-tree-view" true

    # ---[ Step 3: Context menu options ]---
    echo "[+] Enabling 'Create Link' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-create-link" true

    echo "[+] Enabling 'Delete Permanently' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-delete-permanently" true

    # ---[ Step 4: Search, thumbnails, and directory item counts ]---
    echo "[+] Enabling recursive search, image thumbnails, and directory item counts..."
    set_gsetting "org.gnome.nautilus.preferences recursive-search" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-image-thumbnails" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-directory-item-counts" "'always'"

    # ---[ Step 5: Icon view captions ]---
    echo "[+] Configuring grid view captions (type, size, permissions)..."
    set_gsetting "org.gnome.nautilus.icon-view captions" "['detailed_type', 'size', 'permissions']"

    # ---[ Step 6: Show hidden files everywhere ]---
    echo "[+] Enabling display of hidden files everywhere..."
    set_gsetting "org.gtk.Settings.FileChooser show-hidden" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser show-hidden" true
    set_gsetting "org.gnome.nautilus.preferences show-hidden-files" true

    echo "[*] File manager preferences configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GNOME Terminal Settings Configuration
# ----------------------------------------------
configure_gnome_terminal_settings() {
    : '
    Configure GNOME Terminal preferences.

    Description:
        - Rename the default GNOME Terminal profile to "root".
        - Disable system theme colors to apply custom colors.
        - Set custom foreground and background colors for better readability.
        - Enable transparency using the theme settings.
        - Set a custom color palette for consistent terminal appearance.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting GNOME Terminal preferences configuration."
    echo "-----------------------------"

    # ---[ Step 1: Retrieve default profile ID ]---
    echo "[*] Retrieving the ID of the default terminal profile..."
    default_profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
    default_profile=${default_profile:1:-1}  # Remove leading and trailing single quotes

    # ---[ Step 2: Rename profile and adjust color settings ]---
    echo "[+] Renaming the default profile to 'root'..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/visible-name "'root'"

    echo "[+] Disabling basic system theme (use-theme-colors)..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-colors false

    echo "[+] Setting custom foreground and background colors..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/foreground-color "'rgb(208,207,204)'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/background-color "'rgb(23,20,33)'"

    # ---[ Step 3: Enable transparency ]---
    echo "[+] Enabling transparency (theme transparency)..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-transparency true

    # ---[ Step 4: Set custom color palette ]---
    echo "[+] Setting up the color palette..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/palette "['rgb(23,20,33)', 'rgb(192,28,40)', 'rgb(38,162,105)', 'rgb(162,115,76)', 'rgb(18,72,139)', 'rgb(163,71,186)', 'rgb(42,161,179)', 'rgb(208,207,204)', 'rgb(94,92,100)', 'rgb(246,97,81)', 'rgb(51,209,122)', 'rgb(233,173,12)', 'rgb(42,123,222)', 'rgb(192,97,203)', 'rgb(51,199,222)', 'rgb(255,255,255)']"

    echo "[*] GNOME Terminal preferences configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GNOME Shell & Text Editor Settings Configuration
# ----------------------------------------------
configure_gnome_shell_text_editor_settings() {
    : '
    Configure GNOME Shell favorites and GNOME Text Editor settings.

    Description:
        - Set favorite applications in GNOME Shell (Dock).
        - Customize GNOME Text Editor appearance and usability:
          line numbers, right margin, dark theme, grid pattern, line highlight,
          disable spellcheck, and enable text wrapping.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting GNOME Shell favorites and Text Editor configuration."
    echo "-----------------------------"

    # ---[ Step 1: Configure GNOME Shell favorite applications ]---
    echo "[+] Setting favorite applications in GNOME Shell..."
    set_gsetting "org.gnome.shell favorite-apps" "['firefox_firefox.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop']"

    # ---[ Step 2: Configure GNOME Text Editor settings ]---
    echo "[+] Enabling line numbers in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor show-line-numbers" true

    echo "[+] Enabling right margin in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor show-right-margin" true

    echo "[+] Applying dark theme to GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor style-variant" "'dark'"
    set_gsetting "org.gnome.TextEditor style-scheme" "'classic-dark'"

    echo "[+] Enabling grid pattern and line highlight in Text Editor..."
    set_gsetting "org.gnome.TextEditor highlight-current-line" true
    set_gsetting "org.gnome.TextEditor show-grid" true

    echo "[+] Disabling spellcheck in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor spellcheck" false

    echo "[+] Enabling text wrapping in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor wrap-text" true

    echo "[*] GNOME Shell favorites and Text Editor configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# System Settings Global Configuration
# ----------------------------------------------
configure_system_settings() {
    : '
    Main function to configure all system settings.

    Description:
        - Apply global configuration for GNOME and Ubuntu desktop environment.
        - Covers appearance, privacy, performance, usability, and essential settings.
        - Calls all other dedicated configuration functions in a predefined order.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting system settings configuration."
    echo "-----------------------------"

    # ---[ Step 1: Theme and appearance ]---
    configure_theme
    configure_ubuntu_desktop

    # ---[ Step 2: Privacy and security ]---
    configure_privacy_settings

    # ---[ Step 3: System sound and performance ]---
    configure_sound_settings
    configure_power_perfs_settings

    # ---[ Step 4: Display, keyboard, and clock ]---
    configure_display_settings
    configure_keyboard_settings
    configure_calendar_clock_settings

    # ---[ Step 5: File manager and GNOME apps ]---
    configure_file_manager_settings
    configure_gnome_terminal_settings
    configure_gnome_shell_text_editor_settings

    echo "[*] All system settings configurations completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Disable a Specific systemd Service
# ----------------------------------------------
disable_service() {
    : '
    Disable a specified systemd service if currently enabled.

    Description:
        - Checks if the given systemd service is enabled.
        - If enabled, disables it to prevent automatic startup.
        - If already disabled, takes no action.

    Args:
        $1 (string): Name of the systemd service to disable (e.g., "bluetooth.service").

    Returns:
        None
    '

    local service="$1"

    echo "[+] Ensuring $service is disabled..."

    # ---[ Step 1: Check if service is enabled ]---
    if sudo systemctl is-enabled "$service" &>/dev/null; then
        # ---[ Step 2: Disable the service if needed ]---
        echo "[+] Disabling $service..."
        sudo systemctl disable "$service"
    else
        echo "[=] $service is already disabled."
    fi
}


# ----------------------------------------------
# Remove a Specified Package Using apt
# ----------------------------------------------
remove_package() {
    : '
    Remove a specified package using apt if installed.

    Description:
        - Check if the given package is installed on the system.
        - If installed, remove it completely using apt with --purge to delete configuration files.
        - If not installed, do nothing.

    Args:
        $1 (string): Name of the package to remove (e.g., "vim", "bluetooth").

    Returns:
        None
    '

    local package="$1"

    echo "[+] Ensuring $package is not installed..."

    # ---[ Step 1: Check if package is installed ]---
    if dpkg -s "$package" &>/dev/null; then
        # ---[ Step 2: Remove the package if present ]---
        echo "[+] Removing $package..."
        sudo apt remove --purge -y "$package"
    else
        echo "[=] $package is already not installed."
    fi
}


# ----------------------------------------------
# System Hardening Configuration
# ----------------------------------------------
configure_hardening() {
    : '
    Perform system hardening by disabling unnecessary services,
    removing dangerous packages, and applying essential security measures.

    Description:
        - Disable the root account to prevent direct login.
        - Install USBGuard if internet connection is available.
        - Disable dangerous and unnecessary system services.
        - Remove unused and risky packages that may expose vulnerabilities.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting system hardening configuration."
    echo "-----------------------------"

    # ---[ Step 1: Disable root account ]---
    echo "[+] Disabling root account..."
    sudo passwd -l root  # To re-enable: sudo passwd -u root

    # ---[ Step 2: Install security tools if connected to the Internet ]---
    if check_internet_connectivity; then
        echo "[+] Internet connectivity confirmed. Installing security tools..."
        echo "[+] Installing usbguard..."
        sudo apt install usbguard -y
    else
        echo "[!] Skipping security tools installation (no internet connection)."
    fi

    # ---[ Step 3: Disable unnecessary and dangerous services ]---
    echo "[*] Disabling unnecessary services..."
    local services=(
        slapd nfs-server rpcbind bind9 vsftpd apache2 dovecot exim
        cyrus-imap smbd squid snmpd postfix sendmail rsync nis
    )
    for service in "${services[@]}"; do
        disable_service "$service"
    done

    # ---[ Step 4: Remove unnecessary and risky packages ]---
    echo "[*] Removing dangerous or useless packages..."
    local packages=(
        nis rsh-client rsh-redone-client talk telnet ldap-utils
    )
    for package in "${packages[@]}"; do
        remove_package "$package"
    done

    echo "[*] System hardening completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Install a .deb Package from URL
# ----------------------------------------------
install_deb_from_url() {
    : '
    Download and install a .deb package from a provided URL.

    Description:
        - Check for internet connectivity before attempting download.
        - Download the specified .deb package using curl.
        - Install the package using dpkg and attempt to fix broken dependencies if needed.
        - Clean up the downloaded .deb file after installation.

    Args:
        url (string): URL to the .deb file to be downloaded and installed.

    Returns:
        0 if installation succeeds, 1 if failed or no internet.
    '

    local url="$1"
    local deb_name

    echo "-----------------------------"
    echo "[*] Attempting to install .deb package from URL: $url"
    echo "-----------------------------"

    # ---[ Step 1: Check Internet Connectivity ]---
    if ! check_internet_connectivity; then
        echo "[!] No internet connectivity. Skipping installation from $url."
        echo "-----------------------------"
        return 1
    fi

    echo "[+] Internet connectivity confirmed. Downloading package..."

    # ---[ Step 2: Download the .deb Package ]---
    if curl -LO "$url"; then
        deb_name=$(basename "$url")
        echo "[+] Downloaded $deb_name."

        # ---[ Step 3: Install the .deb Package ]---
        echo "[+] Installing $deb_name..."
        if sudo dpkg -i "$deb_name"; then
            echo "[+] $deb_name installed successfully."
        else
            echo "[!] Installation failed. Attempting to fix dependencies..."
            sudo apt install -f -y
        fi

        # ---[ Step 4: Cleanup Downloaded File ]---
        echo "[+] Cleaning up temporary file..."
        rm -f "$deb_name"
        echo "[=] Temporary file $deb_name removed."
    else
        echo "[!] Failed to download $url. Skipping."
    fi

    echo "-----------------------------"
}


# ----------------------------------------------
# Install Basic Applications and Useful Tools
# ----------------------------------------------
install_basic_apps() {
    : '
    Install a list of essential applications and tools for daily use.

    Description:
        - Install APT packages for system utilities, development, and productivity.
        - Refresh and install Snap packages, including classic confinement apps.
        - Check and install Mullvad VPN if not already present.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting basic application installation."
    echo "-----------------------------"

    # ---[ Step 1: Install APT Packages ]---
    local apt_packages=(
        nala zulucrypt-gui keepassxc vim git curl tmux mat2 rssguard
        python3 python3-pip python3-venv zsh taskwarrior net-tools
        # Optional GNOME apps (uncomment if needed):
        # gnome-software gnome-shell-extension-manager gnome-tweaks
        # hicolor-icon-theme gnome-menus desktop-file-utils gnome-maps
        # gnome-weather gnome-calendar gnome-clocks
    )

    echo "[+] Installing APT packages..."
    sudo apt update
    sudo apt install -y "${apt_packages[@]}"
    echo "[+] APT packages installed."

    # ---[ Step 2: Refresh and Install Snap Packages ]---
    echo "[+] Refreshing Snap packages..."
    sudo snap refresh

    local snap_packages=(
        "xmind --classic"
        "obsidian --classic"
        "lsd"
    )

    echo "[+] Installing Snap packages..."
    for snap_pkg in "${snap_packages[@]}"; do
        echo "[*] Installing $snap_pkg..."
        sudo snap install $snap_pkg
    done
    echo "[+] Snap packages installed."

    # ---[ Step 3: Install Mullvad VPN if not already installed ]---
    echo "[+] Checking Mullvad VPN installation..."
    if dpkg -s mullvad-vpn > /dev/null 2>&1; then
        echo "[=] Mullvad VPN is already installed. Skipping installation."
    else
        echo "[+] Installing Mullvad VPN..."
        install_deb_from_url "https://mullvad.net/download/app/deb/latest"
    fi

    echo "-----------------------------"
    echo "[*] Basic application installation completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Manage Firefox Profiles
# ----------------------------------------------
manage_firefox_profiles() {
    : '
    Manage Firefox profiles for a fresh and secured setup.

    Description:
        - Locate and delete existing Firefox profiles.
        - Create a new "root" profile for clean usage.
        - Launch Firefox with the new profile to initialize it.
        - Download and apply a custom user.js configuration file from a remote source (Pastebin RAW).

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Firefox profile management."
    echo "-----------------------------"

    # ---[ Step 1: Locate profile directory ]---
    local profiles_ini
    profiles_ini=$(find ~ -name 'profiles.ini' -print 2>/dev/null | head -n 1)

    if [[ -z "$profiles_ini" ]]; then
        echo "[!] No profiles.ini file found. Firefox might not be installed yet."
        echo "-----------------------------"
        return
    fi

    local profile_dir
    profile_dir=$(dirname "$profiles_ini")
    echo "[+] Profile directory found: $profile_dir"

    # ---[ Step 2: Delete old profiles ]---
    echo "[+] Deleting old profiles..."
    find "$profile_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;
    echo "[=] Old profiles removed."

    # ---[ Step 3: Create new 'root' profile ]---
    echo "[+] Creating 'root' profile..."
    if firefox -CreateProfile "root $profile_dir/root" >/dev/null 2>&1; then
        echo "[=] 'root' profile created."
    else
        echo "[!] Failed to create 'root' profile."
    fi

    # ---[ Step 4: Initialize profile by launching Firefox ]---
    echo "[+] Launching Firefox with 'root' profile to initialize it..."
    firefox -P "root" & disown
    sleep 5

    # ---[ Step 5: Close Firefox gracefully ]---
    echo "[+] Closing Firefox..."
    pkill -f "firefox -P root"

    # ---[ Step 6: Download and apply custom user.js ]---
    local user_js_url="https://pastebin.com/raw/ZX70EYvN"
    local user_js_dest="$profile_dir/root/user.js"

    echo "[+] Downloading user.js from $user_js_url..."
    if curl -fsSL "$user_js_url" -o "$user_js_dest"; then
        echo "[=] user.js downloaded and applied to root profile."
    else
        echo "[!] Failed to download user.js. Skipping custom configuration."
    fi

    echo "-----------------------------"
    echo "[*] Firefox profile management completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Install SpaceVim
# ----------------------------------------------
install_spacevim() {
    : '
    Installs SpaceVim, a community-driven modular Vim distribution.

    Description:
        - Check for internet connectivity and curl presence before proceeding.
        - Download and execute the official SpaceVim installation script.
        - Provide feedback on success or failure.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting SpaceVim installation."
    echo "-----------------------------"

    # ---[ Step 1: Check for Internet Connectivity ]---
    if ! check_internet_connectivity; then
        echo "[!] No internet connection. Skipping SpaceVim installation."
        echo "-----------------------------"
        return
    fi
    echo "[+] Internet connection confirmed."

    # ---[ Step 2: Check if curl is installed ]---
    if ! command -v curl &>/dev/null; then
        echo "[!] curl is required but not installed. Skipping SpaceVim installation."
        echo "-----------------------------"
        return
    fi

    # ---[ Step 3: Download and Run SpaceVim Installer ]---
    echo "[+] Downloading and running the SpaceVim installer..."
    if curl -sLf https://spacevim.org/install.sh | bash; then
        echo "[=] SpaceVim installed successfully."
    else
        echo "[!] SpaceVim installation failed. Please check your connection or the installer URL."
    fi

    echo "-----------------------------"
}


# ----------------------------------------------
# Install Nerd Fonts
# ----------------------------------------------
install_nerd_fonts() {
    : '
    Install Nerd Fonts if the font directory exists.

    Description:
        - Check if the Nerd Fonts directory is available locally.
        - Copy all .ttf fonts from the source directory to the user fonts directory.
        - Refresh font cache if fonts were installed.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Nerd Fonts installation."
    echo "-----------------------------"

    local font_dir="assets/fonts/NerdFonts/"
    local target_dir="$HOME/.local/share/fonts/"

    # ---[ Step 1: Check if the Nerd Fonts directory exists ]---
    if [ ! -d "$font_dir" ]; then
        echo "[!] Nerd Fonts directory not found at $font_dir. Skipping installation."
        echo "-----------------------------"
        return
    fi
    echo "[+] Nerd Fonts directory found: $font_dir"

    # ---[ Step 2: Ensure target fonts directory exists ]---
    mkdir -p "$target_dir"

    # ---[ Step 3: Copy fonts and track installation success ]---
    local font_installed=false
    for font in "$font_dir"*.ttf; do
        if [ -f "$font" ]; then
            echo "[+] Installing font: $(basename "$font")"
            if cp "$font" "$target_dir"; then
                font_installed=true
            else
                echo "[!] Failed to install $(basename "$font")."
            fi
        fi
    done

    # ---[ Step 4: Update font cache if fonts were installed ]---
    if [ "$font_installed" = true ]; then
        echo "[+] Updating font cache..."
        fc-cache -f "$target_dir"
        echo "[=] Nerd Fonts installed and cache updated."
    else
        echo "[!] No .ttf fonts found in $font_dir. Nothing was installed."
    fi

    echo "-----------------------------"
}


# ----------------------------------------------
# Install Oh My Zsh
# ----------------------------------------------
install_ohmyzsh() {
    : '
    Install Oh My Zsh, a community-driven framework for managing Zsh configuration.

    Description:
        - Check for internet connectivity and presence of Zsh.
        - Install Oh My Zsh unattended if not already installed.
        - Clear bash history for security.
        - Set Zsh as the default shell if not already set.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Oh My Zsh installation."
    echo "-----------------------------"

    # ---[ Step 1: Check for Internet Connectivity ]---
    if ! check_internet_connectivity; then
        echo "[!] Skipping Oh My Zsh installation: No internet connection."
        echo "-----------------------------"
        return
    fi
    echo "[+] Internet connectivity confirmed. Proceeding with Oh My Zsh installation."

    # ---[ Step 2: Check if Zsh is Installed ]---
    if ! command -v zsh &> /dev/null; then
        echo "[!] Zsh is not installed. Please install it first. Aborting."
        echo "-----------------------------"
        return
    fi

    # ---[ Step 3: Check and Install Oh My Zsh if Needed ]---
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "[=] Oh My Zsh is already installed. Skipping installation."
    else
        echo "[+] Installing Oh My Zsh..."

        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            echo "[+] Oh My Zsh installed successfully."
        else
            echo "[!] Oh My Zsh installation failed."
            echo "-----------------------------"
            return
        fi
    fi

    # ---[ Step 4: Clear Bash History for Security ]---
    echo "[+] Clearing bash history..."
    history -c
    rm -f ~/.bash_history

    # ---[ Step 5: Change Default Shell to Zsh if Needed ]---
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "[+] Changing default shell to Zsh..."
        if sudo chsh -s "$(which zsh)" "$USER"; then
            echo "[=] Default shell changed to Zsh."
        else
            echo "[!] Failed to change default shell to Zsh. You may need to do it manually."
        fi
    else
        echo "[=] Zsh is already the default shell."
    fi

    echo "[*] Oh My Zsh installation and configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Zsh Customization (Powerlevel10k + Plugins)
# ----------------------------------------------
custom_zsh() {
    : '
    Customize Zsh with Powerlevel10k theme and various Zsh plugins.

    Description:
        - Ensure Zsh is installed and set as the default shell.
        - Install Powerlevel10k theme if not already present.
        - Install key Zsh plugins (autosuggestions, syntax highlighting, completions).
        - Configure the .zshrc file to use the theme and plugins.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh customization."
    echo "-----------------------------"

    # ---[ Step 1: Save current shell ]---
    local original_shell="$SHELL"

    # ---[ Step 2: Ensure Zsh is installed ]---
    if ! command -v zsh &> /dev/null; then
        echo "[!] Zsh is not installed. Please install Zsh first."
        echo "-----------------------------"
        return
    fi

    # ---[ Step 3: Check Internet connectivity ]---
    if ! check_internet_connectivity; then
        echo "[!] Internet connectivity is required. Skipping Zsh customization."
        echo "-----------------------------"
        return
    fi

    # ---[ Step 4: Change default shell to Zsh if needed ]---
    if [ "$SHELL" != "$(which zsh)" ]; then
        echo "[+] Changing default shell to Zsh..."
        if sudo chsh -s "$(which zsh)" "$USER"; then
            echo "[=] Default shell changed to Zsh."
        else
            echo "[!] Failed to change default shell to Zsh."
        fi
    else
        echo "[=] Zsh is already the default shell."
    fi

    # ---[ Step 5: Install Powerlevel10k Theme ]---
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        echo "[+] Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" || echo "[!] Failed to clone Powerlevel10k."
    else
        echo "[=] Powerlevel10k is already installed."
    fi

    # ---[ Step 6: Set Powerlevel10k as Zsh Theme ]---
    if grep -q '^ZSH_THEME=' ~/.zshrc; then
        echo "[+] Setting Powerlevel10k as Zsh theme..."
        sed -i 's/^ZSH_THEME="[^"]*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    else
        echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
    fi

    # ---[ Step 7: Install Zsh Plugins ]---
    echo "[+] Installing Zsh plugins..."
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    declare -A plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
    )

    for plugin in "${!plugins[@]}"; do
        local plugin_path="$plugins_dir/$plugin"
        if [ ! -d "$plugin_path" ]; then
            echo "[+] Installing $plugin..."
            git clone --depth=1 "${plugins[$plugin]}" "$plugin_path" || echo "[!] Failed to clone $plugin."
        else
            echo "[=] $plugin already installed."
        fi
    done

    # ---[ Step 8: Add Plugins to .zshrc ]---
    if grep -q '^plugins=' ~/.zshrc; then
        echo "[+] Updating plugins list in .zshrc..."
        sed -i 's/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' ~/.zshrc
    else
        echo "plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)" >> ~/.zshrc
    fi

    echo "[*] Zsh customization completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Update Zsh Plugins
# ----------------------------------------------
update_zsh_plugins() {
    : '
    Update the Zsh configuration (.zshrc) with a predefined set of plugins.

    Description:
        - Add a large set of useful Zsh plugins for productivity and development.
        - Preserve essential plugins (zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions)
          if already present in the current configuration.
        - Ensure there are no duplicates in the final plugin list.
        - Backup the existing .zshrc before applying changes.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh plugins update."
    echo "-----------------------------"

    local zshrc="$HOME/.zshrc"

    # ---[ Step 1: Verify .zshrc exists ]---
    if [ ! -f "$zshrc" ]; then
        echo "[!] No .zshrc file found. Skipping plugin update."
        echo "-----------------------------"
        return
    fi

    # ---[ Step 2: Define list of desired plugins ]---
    local plugins_to_add=(
        git aliases autopep8 aws colored-man-pages colorize command-not-found
        common-aliases compleat copybuffer copyfile copypath cp docker
        docker-compose emoji emoji-clock emotty encode64 extract fancy-ctrl-z
        fbterm genpass git-commit git-escape-magic gitignore git-prompt golang
        history hitokoto httpie jsontools kubectl kubectx lol man nmap pip
        qrcode python rust sublime sudo systemadmin systemd taskwarrior terraform
        themes timer tmux tmuxinator torrent transfer ubuntu ufw urltools
        vagrant vscode web-search
    )

    # ---[ Step 3: Preserve essential plugins if present ]---
    for essential_plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
        if grep -q "$essential_plugin" "$zshrc"; then
            plugins_to_add+=("$essential_plugin")
        fi
    done

    # ---[ Step 4: Remove duplicates ]---
    mapfile -t plugins_to_add < <(printf "%s\n" "${plugins_to_add[@]}" | sort -u)

    # ---[ Step 5: Backup existing .zshrc ]---
    cp "$zshrc" "$zshrc.bak"
    echo "[=] Backup of .zshrc created at $zshrc.bak"

    # ---[ Step 6: Build plugins line ]---
    local formatted_plugins
    formatted_plugins="plugins=(${plugins_to_add[*]})"

    # ---[ Step 7: Update or add plugins list in .zshrc ]---
    if grep -q "^plugins=" "$zshrc"; then
        echo "[+] Updating existing plugins list..."
        sed -i "s/^plugins=(.*)/$formatted_plugins/" "$zshrc"
    else
        echo "[+] Adding plugins list to .zshrc..."
        echo -e "\n$formatted_plugins" >> "$zshrc"
    fi

    echo "[*] Zsh plugins updated successfully."
    echo "-----------------------------"
}


# ----------------------------------------------
# Update Zsh Aliases
# ----------------------------------------------
update_zsh_aliases() {
    : '
    Update the Zsh configuration (.zshrc) with a new set of custom aliases.

    Description:
        - Safely remove any existing block of custom aliases marked between # >>> and # <<<.
        - Add an updated set of useful custom aliases for productivity and system management.
        - Backup the existing .zshrc file before making any changes.

    Args:
        None

    Returns:
        None
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh aliases update."
    echo "-----------------------------"

    local zshrc="$HOME/.zshrc"

    # ---[ Step 1: Check if .zshrc exists ]---
    if [ ! -f "$zshrc" ]; then
        echo "[!] No .zshrc file found. Skipping aliases update."
        echo "-----------------------------"
        return
    fi

    # ---[ Step 2: Backup existing .zshrc ]---
    cp "$zshrc" "$zshrc.bak"
    echo "[=] Backup of .zshrc created at $zshrc.bak"

    # ---[ Step 3: Remove existing alias block ]---
    sed -i '/# >>> CUSTOM ALIASES >>>/,/# <<< CUSTOM ALIASES <<</d' "$zshrc"

    # ---[ Step 4: Define new alias block ]---
    local new_aliases=$(cat << 'EOF'
# >>> CUSTOM ALIASES >>>
# Custom Aliases
alias calc='bc -l'
alias getrand='openssl rand -base64 42'
alias untar='tar -zxvf'
alias ..='cd ..'
alias cd..='cd ..'
alias la='lsd -A'
alias ls='lsd'
alias l='lsd'
alias ldir='lsd -l | grep -E '\''^d'\'' --color=never'
alias less='less -R'
alias lf='lsd -l | grep -E -v '\''^d'\'''
alias lk='lsd -lSrh'
alias ll='lsd -alFh'
alias lm='lsd -alh | more'
alias lr='lsd -lRh'
alias lt='lsd -ltrh'
alias lx='lsd -lXh'
alias mem='free -m -l -t'
alias ports='sudo netstat -tulanp'
alias psmem='ps auxf | sort -nr -k 4'
alias shpubip='curl http://ipecho.net/plain; echo'
alias checkmv='curl https://am.i.mullvad.net/connected'
alias city='curl https://am.i.mullvad.net/city'
alias country='curl https://am.i.mullvad.net/country'
alias df='df -h'
alias du='du -h'
alias dmesg='dmesg --human'
alias zulu="zuluCrypt-gui"
alias zulucli="zuluCrypt-cli"
alias biggest='du -h --max-depth=1 | sort -h'
alias countfiles='bash -c "for t in files links directories; do echo \$(find . -type \${t:0:1} | wc -l) \$t; done 2> /dev/null"'
alias da='date "+%Y-%m-%d %A %T %Z"'
alias diskspace='du -S | sort -n -r |more'
alias folders='du -h --max-depth=1'
alias follow='tail -f -n +1'
alias ipview='netstat -anpl | grep :80 | awk {'\''print $5'\''} | cut -d":" -f1 | sort | uniq -c | sort -n | sed -e '\''s/^ *//'\'' -e '\''s/ *$//'\'''
alias iso='cat /etc/dev-rel | awk -F '\''='\'' '\''/ISO/ {print }'\'''
alias j='jobs'
alias jctl='journalctl -p 3 -xb'
alias logs='sudo find /var/log -type f -exec file {} \; | grep '\''text'\'' | cut -d'\'' '\'' -f1 | sed -e'\''s/:$//g'\'' | grep -v '\''[0-9]$'\'' | xargs tail -f'
alias mkdir='mkdir -p'
alias mountedinfo='df -hT'
alias open='xdg-open'
alias openports='netstat -nape --inet'
# <<< CUSTOM ALIASES <<<
EOF
)

    # ---[ Step 5: Append new aliases to .zshrc ]---
    echo "$new_aliases" >> "$zshrc"
    echo "[+] Custom aliases successfully added to .zshrc."

    echo "-----------------------------"
}


# ----------------------------------------------
# Copy Powerlevel10k Configuration from URL
# ----------------------------------------------
copy_p10k_config() {
    : '
    Downloads and applies the Powerlevel10k (.p10k.zsh) configuration file
    from a remote URL (Pastebin RAW link).

    Description:
        - Check for internet connectivity before attempting download.
        - Backup existing .p10k.zsh if already present.
        - Download and apply new .p10k.zsh from specified URL.

    Args:
        None

    Returns:
        0 if download succeeds, 1 if failed (e.g., no internet or URL error).
    '

    echo "-----------------------------"
    echo "[*] Starting Powerlevel10k configuration setup."
    echo "-----------------------------"

    local p10k_url="https://pastebin.com/raw/U3g4iaPw"
    local target="$HOME/.p10k.zsh"

    # ---[ Step 1: Check for Internet connection ]---
    if ! check_internet_connectivity; then
        echo "[!] No internet connection. Cannot download Powerlevel10k configuration."
        echo "-----------------------------"
        return 1
    fi

    # ---[ Step 2: Backup existing .p10k.zsh if found ]---
    if [ -f "$target" ]; then
        echo "[=] Existing .p10k.zsh found. Backing up to ${target}.bak"
        cp "$target" "${target}.bak"
    fi

    # ---[ Step 3: Download new .p10k.zsh from URL ]---
    echo "[+] Downloading .p10k.zsh from $p10k_url..."
    if curl -fsSL "$p10k_url" -o "$target"; then
        echo "[=] .p10k.zsh successfully downloaded and applied to $HOME/."
    else
        echo "[!] Failed to download .p10k.zsh. Check URL or connectivity."
        echo "-----------------------------"
        return 1
    fi

    echo "-----------------------------"
}


# ----------------------------------------------
# Main Function - Post-Installation Script
# ----------------------------------------------
main() {
    : '
    Main function that orchestrates the entire post-installation process.

    Description:
        - Display banner and initialize the post-installation process.
        - Execute all configuration and installation steps in a defined order.
        - Provide feedback for each step and handle errors gracefully.

    Args:
        None

    Returns:
        None (Script exits with code 0 when completed)
    '

    clear
    show_banner
    echo

    echo ">>> Starting post-installation script <<<"

    # ---[ Step 1: Define ordered steps to execute ]---
    local steps=(
        "perform_system_update"
        "configure_ufw"
        "configure_system_settings"
        "configure_hardening"
        "install_basic_apps"
        "manage_firefox_profiles"
        "install_spacevim"
        "install_nerd_fonts"
        "install_ohmyzsh"
        "custom_zsh"
        "update_zsh_plugins"
        "update_zsh_aliases"
        "copy_p10k_config"
    )

    # ---[ Step 2: Execute each step and handle errors ]---
    for step in "${steps[@]}"; do
        echo -e "\n[*] Running: $step..."
        if ! $step; then
            echo "[!] Error during $step. Check logs."
            # Optional: Uncomment the next line if you want to stop on error
            # exit 1
        fi
    done

    # ---[ Step 3: Completion message ]---
    echo -e "\n>>> Post-installation script completed. <<<"
    exit 0
}

# ---[ Require root privileges before starting ]---
require_admin_rights
main

