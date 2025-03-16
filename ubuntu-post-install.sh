#!/bin/bash

: '
Ubuntu Post-Installation Script
This script has been originally developed on Ubuntu 23.10 (Mantic Minotaur), but also tested and running smoothly on Ubuntu 24.04 (Noble Numbat).
While it might work on other versions or derivatives of Ubuntu, full compatibility is only guaranteed on Ubuntu 23.10.

Created By  : Franck FERMAN (@franckferman)
Created Date: 06/12/2023
Version     : 1.0.0
'


# ----------------------------------------------
# Root Privilege Verification
# ----------------------------------------------
require_admin_rights() {
    : '
    Ensure that the user has administrative (root) privileges.

    - Prompt for sudo if not already active.
    - Keep sudo session alive during script execution.
    
    Exits the script if sudo rights are not available.
    '

    # Check if sudo works, otherwise exit
    if ! sudo -v; then
        echo "❌ This script requires administrative privileges. Please run it as a user with sudo rights."
        exit 1
    fi

    # Keep sudo session alive until the script finishes
    while true; do 
        sudo -n true  # Renew sudo session without prompting
        sleep 60      # Refresh every 60 seconds
        kill -0 "$$" || exit  # Exit loop if parent script terminates
    done 2>/dev/null &
}


# ----------------------------------------------
# Initial Banner
# ----------------------------------------------
show_banner() {
    : '
    Display a banner for the post-installation script.
    
    Adds a simple ASCII art to introduce the script when executed.
    '

    cat << "EOF"
     ,-O
    O(_)) Ubuntu post-install script
     `-O 
EOF
}


# ----------------------------------------------
# Internet Check
# ----------------------------------------------
check_internet_connectivity() {
    : '
    Check internet connectivity by pinging a specified host (default: 1.1.1.1).

    Args:
        $1 (optional): IP address or domain to ping. Defaults to 1.1.1.1.

    Returns:
        0 if the host is reachable, 1 otherwise.
    '
    local host="${1:-1.1.1.1}"
    ping -c 2 -W 5 "$host" > /dev/null 2>&1
    return $?
}


# ----------------------------------------------
# System Update
# ----------------------------------------------
perform_system_update() {
    : '
    Perform a complete system update if internet connectivity is available.

    - Updates package lists.
    - Upgrades all packages.
    - Cleans up unused packages and dependencies.

    Skips if no internet connection is detected.
    '

    echo "-----------------------------"
    echo "[*] System update process initiated."
    echo "-----------------------------"

    if check_internet_connectivity; then
        echo -e "\n[+] Internet connectivity confirmed. Proceeding with system updates..."

        # Update package information
        echo -e "\n[+] Updating package lists (apt update)..."
        sudo apt update

        # Upgrade all packages
        echo -e "\n[+] Upgrading all packages (apt full-upgrade)..."
        sudo apt full-upgrade -y

        # Clean up unused packages and dependencies
        echo -e "\n[+] Cleaning apt cache (apt autoclean)..."
        sudo apt autoclean -y

        echo -e "\n[+] Removing unused packages (apt autoremove)..."
        sudo apt autoremove -y

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
    Configure Uncomplicated Firewall (UFW) settings:
    - Enable UFW if inactive.
    - Set default rules (deny incoming, allow outgoing).
    '

    echo "-----------------------------"
    echo "[*] UFW configuration process initiated."
    echo "-----------------------------"

    # Check if UFW is active
    if ! sudo ufw status | grep -q "Status: active"; then
        echo "[+] Enabling UFW..."
        sudo ufw enable
    else
        echo "[=] UFW is already active."
    fi

    echo "[+] Setting up UFW default rules..."

    # Set default rules
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    echo "[*] UFW configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GSettings Update Utility
# ----------------------------------------------
set_gsetting() {
    : '
    Update a gsettings key with a new value if different from the current value.
    Args:
        key (str): The gsettings key to set.
        value (str): The value to assign to the key.
    '
    local key=$1
    local value=$2
    local current_value

    echo -e "\n[*] Processing gsetting for key: $key"

    # Get the current value of the gsettings key
    current_value=$(gsettings get $key 2> /dev/null)

    # Check if the key exists
    if [ $? -ne 0 ]; then
        echo "[!] The key $key does not exist."
        return
    fi

    # Update the key if the current value is different
    if [ "$current_value" != "$value" ]; then
        echo "[+] Setting $key to $value."
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
    Configure the theme settings for the GNOME desktop environment.
    '

    echo "-----------------------------"
    echo "[*] Starting theme configuration."
    echo "-----------------------------"

    echo "[+] Applying dark color scheme..."
    set_gsetting "org.gnome.desktop.interface color-scheme" "'prefer-dark'"

    echo "[*] Searching for available themes..."
    themes=$(ls -d /usr/share/themes/* 2>/dev/null | xargs -L 1 basename)

    if [ -z "$themes" ]; then
        echo "[!] No additional themes found. Skipping theme setup."
    else
        if echo "$themes" | grep -q "Yaru-red-dark"; then
            echo "[+] Found and applying 'Yaru-red-dark' theme."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Yaru-red-dark'"
        elif echo "$themes" | grep -q "Adwaita-dark"; then
            echo "[+] 'Yaru-red-dark' not found. Applying fallback 'Adwaita-dark' theme."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Adwaita-dark'"
        else
            echo "[!] No suitable dark theme found. Theme unchanged."
        fi
    fi

    echo "[*] Setting solid black as desktop background..."

    for key in primary-color secondary-color; do
        if gsettings writable org.gnome.desktop.background "$key" > /dev/null 2>&1; then
            echo "[+] Setting $key to black."
            set_gsetting "org.gnome.desktop.background.$key" "#000000"
        else
            echo "[!] Cannot write to $key."
        fi
    done

    for key in picture-uri picture-uri-dark; do
        if gsettings writable org.gnome.desktop.background "$key" > /dev/null 2>&1; then
            echo "[+] Setting $key to empty (black background)."
            set_gsetting "org.gnome.desktop.background.$key" "''"
        else
            echo "[!] Cannot write to $key."
        fi
    done

    echo "[*] Theme configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GNOME Ubuntu Desktop Configuration
# ----------------------------------------------
configure_ubuntu_desktop() {
    : '
    Configure the Ubuntu GNOME desktop environment (Dock, icons placement, etc.).
    '

    echo "-----------------------------"
    echo "[*] Starting Ubuntu desktop configuration."
    echo "-----------------------------"

    echo "[+] Setting new icons to appear at the top-left corner."
    set_gsetting "org.gnome.shell.extensions.ding start-corner" "'top-left'"

    echo "[+] Disabling panel mode (Dash to Dock)."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock extend-height" false

    echo "[+] Setting Dash to Dock icon size to 42."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock dash-max-icon-size" 42

    echo "[*] Ubuntu desktop configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Privacy Settings
# ----------------------------------------------
configure_privacy_settings() {
    : '
    Configure privacy and security-related settings.
    '

    echo "-----------------------------"
    echo "[*] Starting privacy configuration."
    echo "-----------------------------"

    echo "[+] Disabling connectivity checking."
    busctl --system set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled "b" 0

    echo "[+] Configuring screen lock settings."
    set_gsetting "org.gnome.desktop.screensaver lock-enabled" true
    set_gsetting "org.gnome.desktop.screensaver lock-delay" "uint32 0"
    set_gsetting "org.gnome.desktop.screensaver idle-activation-enabled" true
    set_gsetting "org.gnome.desktop.session idle-delay" "uint32 300"

    echo "[+] Disabling location services."
    set_gsetting "org.gnome.system.location enabled" false

    echo "[+] Configuring file history settings."
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" true
    set_gsetting "org.gnome.desktop.privacy recent-files-max-age" 1
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" false

    echo "[+] Enabling automatic removal of old trash and temporary files."
    set_gsetting "org.gnome.desktop.privacy remove-old-trash-files" true
    set_gsetting "org.gnome.desktop.privacy remove-old-temp-files" true

    echo "[+] Setting age for considering files as old to 0 (always considered old)."
    set_gsetting "org.gnome.desktop.privacy old-files-age" "uint32 0"

    echo "[+] Disabling technical problem reports."
    set_gsetting "org.gnome.desktop.privacy report-technical-problems" false

    echo "[+] Hiding user identity."
    set_gsetting "org.gnome.desktop.privacy hide-identity" true

    echo "[+] Disabling software usage statistics."
    set_gsetting "org.gnome.desktop.privacy send-software-usage-stats" false

    echo "[+] Disabling remote desktop services (RDP and VNC)."
    set_gsetting "org.gnome.desktop.remote-desktop.rdp enable" false
    set_gsetting "org.gnome.desktop.remote-desktop.vnc enable" false

    echo "[+] Disabling remembering app usage."
    set_gsetting "org.gnome.desktop.privacy remember-app-usage" false

    echo "[*] Privacy configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Sound Settings
# ----------------------------------------------
configure_sound_settings() {
    : '
    Mute system sounds and disable microphone input.
    '

    echo "-----------------------------"
    echo "[*] Starting sound configuration."
    echo "-----------------------------"

    echo "[+] Muting system output (Master)."
    amixer set Master mute

    echo "[+] Disabling input (Capture)."
    amixer set Capture nocap

    echo "[*] Sound configuration completed."
    echo "-----------------------------"
}



# ----------------------------------------------
# Power & Performance Settings
# ----------------------------------------------
configure_power_perfs_settings() {
    : '
    Configure power and performance settings, including timeouts and profiles.
    '

    echo "-----------------------------"
    echo "[*] Starting power and performance configuration."
    echo "-----------------------------"

    echo "[+] Setting power profile to performance."
    set_gsetting "org.gnome.shell last-selected-power-profile" "'performance'"

    echo "[+] Enabling screen dimming."
    set_gsetting "org.gnome.settings-daemon.plugins.power idle-dim" true

    echo "[+] Enabling automatic power saver on low battery."
    set_gsetting "org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery" true

    echo "[+] Temporarily enabling suspend to adjust timeout settings."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'suspend'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'suspend'"

    echo "[+] Setting logout delay to 2 hours."
    set_gsetting "org.gnome.desktop.screensaver logout-delay" "uint32 7200"

    echo "[+] Setting sleep inactive timeout to 2 hours (AC and battery)."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout" 7200
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout" 7200

    echo "[+] Disabling suspend after timeout configuration."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'nothing'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'nothing'"

    echo "[*] Power and performance configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Display & Interface Settings
# ----------------------------------------------
configure_display_settings() {
    : '
    Configure display and interface settings, including battery percentage and Night Light mode.
    '

    echo "-----------------------------"
    echo "[*] Starting display and interface configuration."
    echo "-----------------------------"

    echo "[+] Enabling battery percentage display."
    set_gsetting "org.gnome.desktop.interface show-battery-percentage" true

    echo "[+] Enabling Night Light (automatic from sunset to sunrise)."
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-enabled" true
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-schedule-automatic" true

    echo "[+] Setting Night Light temperature to 2700K."
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-temperature" "uint32 2700"

    echo "[*] Display and interface configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Keyboard Layout Settings
# ----------------------------------------------
configure_keyboard_settings() {
    : '
    Configure keyboard layout: Add French (AZERTY) if not already present.
    '

    echo "-----------------------------"
    echo "[*] Starting keyboard layout configuration."
    echo "-----------------------------"
    
    local current_sources
    current_sources=$(gsettings get org.gnome.desktop.input-sources sources)

    if echo "$current_sources" | grep -q "('xkb', 'fr+azerty')"; then
        echo "[=] French (AZERTY) keyboard layout is already present."
    else
        echo "[+] Adding French (AZERTY) and US keyboard layouts."
        set_gsetting "org.gnome.desktop.input-sources mru-sources" "[('xkb', 'fr+azerty'), ('xkb', 'us')]"
        set_gsetting "org.gnome.desktop.input-sources sources" "[('xkb', 'us'), ('xkb', 'fr+azerty')]"
    fi

    echo "[*] Keyboard layout configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Calendar & Clock Settings
# ----------------------------------------------
configure_calendar_clock_settings() {
    : '
    Configure GNOME calendar and clock settings:
    - Show weekday and date in clock.
    - Enable week numbers in calendar.
    '

    echo "-----------------------------"
    echo "[*] Starting calendar and clock settings configuration."
    echo "-----------------------------"

    echo "[+] Enabling weekday display in clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-weekday" true

    echo "[+] Enabling date display in clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-date" true

    echo "[+] Enabling week numbers in calendar..."
    set_gsetting "org.gnome.desktop.calendar show-weekdate" true

    echo "[*] Calendar and clock settings configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# File Manager Settings
# ----------------------------------------------
configure_file_manager_settings() {
    : '
    Configure GNOME Nautilus and FileChooser preferences:
    - Sorting, views, context menu options, recursive search, hidden files, etc.
    '

    echo "-----------------------------"
    echo "[*] Starting file manager preferences configuration."
    echo "-----------------------------"

    echo "[+] Sorting directories first in file chooser..."
    set_gsetting "org.gtk.Settings.FileChooser sort-directories-first" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser sort-directories-first" true

    echo "[+] Enabling tree view in list mode..."
    set_gsetting "org.gnome.nautilus.list-view use-tree-view" true

    echo "[+] Enabling 'Create Link' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-create-link" true

    echo "[+] Enabling 'Delete Permanently' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-delete-permanently" true

    echo "[+] Enabling recursive search, image thumbnails, and directory item counts..."
    set_gsetting "org.gnome.nautilus.preferences recursive-search" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-image-thumbnails" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-directory-item-counts" "'always'"

    echo "[+] Configuring grid view captions (type, size, permissions)..."
    set_gsetting "org.gnome.nautilus.icon-view captions" "['detailed_type', 'size', 'permissions']"

    echo "[+] Enabling display of hidden files everywhere..."
    set_gsetting "org.gtk.Settings.FileChooser show-hidden" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser show-hidden" true
    set_gsetting "org.gnome.nautilus.preferences show-hidden-files" true

    echo "[*] File manager preferences configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GNOME Terminal Settings
# ----------------------------------------------
configure_gnome_terminal_settings() {
    : '
    Configure GNOME Terminal preferences:
    - Profile name, theme colors, transparency, color scheme.
    '

    echo "-----------------------------"
    echo "[*] Starting GNOME Terminal preferences configuration."
    echo "-----------------------------"

    echo "[*] Retrieving the ID of the default terminal profile..."
    default_profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
    default_profile=${default_profile:1:-1}

    echo "[+] Renaming the default profile to 'root'..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/visible-name "'root'"

    echo "[+] Disabling basic system theme (use-theme-colors)..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-colors false

    echo "[+] Setting custom foreground and background colors..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/foreground-color "'rgb(208,207,204)'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/background-color "'rgb(23,20,33)'"

    echo "[+] Enabling transparency (theme transparency)..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-transparency true

    echo "[+] Setting up the color palette..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/palette "['rgb(23,20,33)', 'rgb(192,28,40)', 'rgb(38,162,105)', 'rgb(162,115,76)', 'rgb(18,72,139)', 'rgb(163,71,186)', 'rgb(42,161,179)', 'rgb(208,207,204)', 'rgb(94,92,100)', 'rgb(246,97,81)', 'rgb(51,209,122)', 'rgb(233,173,12)', 'rgb(42,123,222)', 'rgb(192,97,203)', 'rgb(51,199,222)', 'rgb(255,255,255)']"

    echo "[*] GNOME Terminal preferences configuration completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# GNOME Shell & Text Editor Settings
# ----------------------------------------------
configure_gnome_shell_text_editor_settings() {
    : '
    Configure GNOME Shell favorites and GNOME Text Editor settings:
    - Favorite apps
    - Editor style, layout, and usability settings
    '

    echo "-----------------------------"
    echo "[*] Starting GNOME Shell favorites and Text Editor configuration."
    echo "-----------------------------"

    echo "[+] Setting favorite applications in GNOME Shell..."
    set_gsetting "org.gnome.shell favorite-apps" "['firefox_firefox.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop']"

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
    Main function to configure all system settings, including:
    - Theme and appearance
    - Desktop and privacy settings
    - Power, display, and sound
    - GNOME terminal and editor preferences
    '

    echo "-----------------------------"
    echo "[*] Starting system settings configuration."
    echo "-----------------------------"

    configure_theme
    configure_ubuntu_desktop
    configure_privacy_settings
    configure_sound_settings
    configure_power_perfs_settings
    configure_display_settings
    configure_keyboard_settings
    configure_calendar_clock_settings
    configure_file_manager_settings
    configure_gnome_terminal_settings
    configure_gnome_shell_text_editor_settings

    echo "[*] All system settings configurations completed."
    echo "-----------------------------"
}


# ----------------------------------------------
# Disable a specific systemd service
# ----------------------------------------------
disable_service() {
    : '
    Disable a specified systemd service if enabled.

    Args:
        $1 (str): Name of the systemd service to disable.
    '
    local service="$1"

    echo "[+] Ensuring $service is disabled..."

    if sudo systemctl is-enabled "$service" &>/dev/null; then
        echo "[+] Disabling $service..."
        sudo systemctl disable "$service"
    else
        echo "[=] $service is already disabled."
    fi
}


# ----------------------------------------------
# Remove a specified package using apt
# ----------------------------------------------
remove_package() {
    : '
    Remove a specified package using apt if installed.

    Args:
        $1 (str): Name of the package to remove.
    '
    local package="$1"

    echo "[+] Ensuring $package is not installed..."

    if dpkg -s "$package" &>/dev/null; then
        echo "[+] Removing $package..."
        sudo apt remove --purge -y "$package"
    else
        echo "[=] $package is already not installed."
    fi
}


# ----------------------------------------------
# System hardening
# ----------------------------------------------
configure_hardening() {
    : '
    Perform system hardening by disabling unnecessary services,
    removing dangerous packages, and applying security measures.
    '
    echo "-----------------------------"
    echo "[*] Starting system hardening configuration."
    echo "-----------------------------"

    echo "[+] Disabling root account..."
    sudo passwd -l root  # Use `sudo passwd -u root` to re-enable

    # Install security tools if connected to the Internet
    if check_internet_connectivity; then
        echo "[+] Internet connectivity confirmed. Installing security tools..."
        echo "[+] Installing usbguard..."
        sudo apt install usbguard -y
    else
        echo "[!] Skipping security tools installation (no internet connection)."
    fi

    # Disable unnecessary and potentially dangerous services
    echo "[*] Disabling unnecessary services..."
    local services=(
        slapd nfs-server rpcbind bind9 vsftpd apache2 dovecot exim
        cyrus-imap smbd squid snmpd postfix sendmail rsync nis
    )
    for service in "${services[@]}"; do
        disable_service "$service"
    done

    # Remove unnecessary and risky packages
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
# Install a .deb package from URL
# ----------------------------------------------
install_deb_from_url() {
    : '
    Download and install a .deb package from a provided URL.
    
    Args:
        url (str): URL to the .deb file.
    '
    local url="$1"
    local deb_name

    echo "-----------------------------"
    echo "[*] Attempting to install .deb package from URL: $url"
    echo "-----------------------------"

    if ! check_internet_connectivity; then
        echo "[!] No internet connectivity. Skipping installation from $url."
        echo "-----------------------------"
        return 1
    fi

    echo "[+] Internet connectivity confirmed. Downloading package..."

    # Attempt to download the package
    if curl -LO "$url"; then
        deb_name=$(basename "$url")
        echo "[+] Downloaded $deb_name."

        echo "[+] Installing $deb_name..."
        if sudo dpkg -i "$deb_name"; then
            echo "[+] $deb_name installed successfully."
        else
            echo "[!] Installation failed. Attempting to fix dependencies..."
            sudo apt install -f -y
        fi

        # Cleanup downloaded file
        echo "[+] Cleaning up temporary file..."
        rm -f "$deb_name"
        echo "[=] Temporary file $deb_name removed."
    else
        echo "[!] Failed to download $url. Skipping."
    fi

    echo "-----------------------------"
}


# ----------------------------------------------
# Install basic applications and useful tools
# ----------------------------------------------
install_basic_apps() {
    : '
    Install a list of essential applications and tools.
    '
    echo "-----------------------------"
    echo "[*] Starting basic application installation."
    echo "-----------------------------"

    # List of APT packages to install
    local apt_packages=(
        nala zulucrypt-gui keepassxc vim git curl tmux mat2 rssguard
        python3 python3-pip python3-venv zsh taskwarrior net-tools
        # gnome-software gnome-shell-extension-manager gnome-tweaks 
        # hicolor-icon-theme gnome-menus desktop-file-utils gnome-maps 
        # gnome-weather gnome-calendar gnome-clocks 
    )

    echo "[+] Installing APT packages..."
    sudo apt update
    sudo apt install -y "${apt_packages[@]}"

    echo "[+] APT packages installed."

    echo "[+] Refreshing Snap packages..."
    sudo snap refresh

    # List of Snap packages to install
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

    # Check if Mullvad VPN is already installed
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
# Manage Firefox profiles
# ----------------------------------------------
manage_firefox_profiles() {
    : '
    Manage Firefox profiles:
    - Find and delete existing profiles.
    - Create a new "root" profile.
    - Launch Firefox with the new profile (initialize).
    - Download and apply custom user.js from a remote source (Pastebin RAW).
    '
    echo "-----------------------------"
    echo "[*] Starting Firefox profile management."
    echo "-----------------------------"

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

    # Delete old profiles
    echo "[+] Deleting old profiles..."
    find "$profile_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;
    echo "[=] Old profiles removed."

    # Create a new profile named 'root'
    echo "[+] Creating 'root' profile..."
    firefox -CreateProfile "root $profile_dir/root" >/dev/null 2>&1 && echo "[=] 'root' profile created." || echo "[!] Failed to create 'root' profile."

    # Launch Firefox with 'root' profile to initialize, wait 5 seconds, and close
    echo "[+] Launching Firefox with 'root' profile to initialize it..."
    firefox -P "root" & disown
    sleep 5

    # Kill Firefox gracefully
    echo "[+] Closing Firefox..."
    pkill -f "firefox -P root"

    # URL of the custom user.js file (Pastebin RAW)
    local user_js_url="https://pastebin.com/raw/ZX70EYvN"
    local user_js_dest="$profile_dir/root/user.js"

    # Download and apply custom user.js if available
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
    '

    echo "-----------------------------"
    echo "[*] Starting SpaceVim installation."
    echo "-----------------------------"

    # Check for internet connectivity
    if ! check_internet_connectivity; then
        echo "[!] No internet connection. Skipping SpaceVim installation."
        echo "-----------------------------"
        return
    fi

    echo "[+] Internet connection confirmed."

    # Check if curl is installed
    if ! command -v curl &>/dev/null; then
        echo "[!] curl is required but not installed. Skipping SpaceVim installation."
        echo "-----------------------------"
        return
    fi

    # Download and execute SpaceVim installer
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
    '

    echo "-----------------------------"
    echo "[*] Starting Nerd Fonts installation."
    echo "-----------------------------"

    local font_dir="assets/fonts/NerdFonts/"
    local target_dir="$HOME/.local/share/fonts/"

    # Check if the Nerd Fonts directory exists
    if [ ! -d "$font_dir" ]; then
        echo "[!] Nerd Fonts directory not found at $font_dir. Skipping installation."
        echo "-----------------------------"
        return
    fi

    echo "[+] Nerd Fonts directory found: $font_dir"

    # Ensure the target directory exists
    mkdir -p "$target_dir"

    # Find and copy each .ttf font
    local font_installed=false
    for font in "$font_dir"*.ttf; do
        if [ -f "$font" ]; then
            echo "[+] Installing font: $(basename "$font")"
            cp "$font" "$target_dir" && font_installed=true || echo "[!] Failed to install $font."
        fi
    done

    # Update font cache if at least one font was installed
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
    '

    echo "-----------------------------"
    echo "[*] Starting Oh My Zsh installation."
    echo "-----------------------------"

    # Check for internet connectivity
    if ! check_internet_connectivity; then
        echo "[!] Skipping Oh My Zsh installation: No internet connection."
        echo "-----------------------------"
        return
    fi

    echo "[+] Internet connectivity confirmed. Proceeding with Oh My Zsh installation."

    # Check if Zsh is installed
    if ! command -v zsh &> /dev/null; then
        echo "[!] Zsh is not installed. Please install it first. Aborting."
        echo "-----------------------------"
        return
    fi

    # Check if Oh My Zsh is already installed
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "[=] Oh My Zsh is already installed. Skipping installation."
    else
        echo "[+] Installing Oh My Zsh..."

        # Install Oh My Zsh unattended
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            echo "[+] Oh My Zsh installed successfully."
        else
            echo "[!] Oh My Zsh installation failed."
            echo "-----------------------------"
            return
        fi
    fi

    # Clear bash history for security (optional but aggressive)
    echo "[+] Clearing bash history..."
    history -c
    rm -f ~/.bash_history

    # Change default shell to Zsh if not already set
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
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh customization."
    echo "-----------------------------"

    # Save the current shell
    local original_shell="$SHELL"

    # Ensure Zsh is installed
    if ! command -v zsh &> /dev/null; then
        echo "[!] Zsh is not installed. Please install Zsh first."
        echo "-----------------------------"
        return
    fi

    # Check internet connectivity
    if ! check_internet_connectivity; then
        echo "[!] Internet connectivity is required. Skipping Zsh customization."
        echo "-----------------------------"
        return
    fi

    # Change to Zsh if not already using it
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

    # Install Powerlevel10k theme if not present
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ ! -d "$p10k_dir" ]; then
        echo "[+] Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" || echo "[!] Failed to clone Powerlevel10k."
    else
        echo "[=] Powerlevel10k is already installed."
    fi

    # Set ZSH_THEME to Powerlevel10k
    if grep -q '^ZSH_THEME=' ~/.zshrc; then
        echo "[+] Setting Powerlevel10k as Zsh theme..."
        sed -i 's/^ZSH_THEME="[^"]*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    else
        echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> ~/.zshrc
    fi

    # Install Zsh plugins
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

    # Add plugins to .zshrc
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
    Preserve existing essential plugins like zsh-autosuggestions, zsh-syntax-highlighting, and zsh-completions if already present.
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh plugins update."
    echo "-----------------------------"

    local zshrc="$HOME/.zshrc"

    # Verify .zshrc exists
    if [ ! -f "$zshrc" ]; then
        echo "[!] No .zshrc file found. Skipping plugin update."
        echo "-----------------------------"
        return
    fi

    # List of desired plugins
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

    # Ensure essential plugins are preserved if already present in the existing config
    for essential_plugin in zsh-autosuggestions zsh-syntax-highlighting zsh-completions; do
        if grep -q "$essential_plugin" "$zshrc"; then
            plugins_to_add+=("$essential_plugin")
        fi
    done

    # Remove duplicates (in case some are already in the default list)
    mapfile -t plugins_to_add < <(printf "%s\n" "${plugins_to_add[@]}" | sort -u)

    # Backup .zshrc before modification
    cp "$zshrc" "$zshrc.bak"
    echo "[=] Backup of .zshrc created at $zshrc.bak"

    # Build plugins line
    local formatted_plugins
    formatted_plugins="plugins=(${plugins_to_add[*]})"

    # If plugins=() exists, replace it. If not, add it at the end.
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
    Safely removes any previous alias block and replaces it with updated aliases.
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh aliases update."
    echo "-----------------------------"

    local zshrc="$HOME/.zshrc"

    # Check if .zshrc exists
    if [ ! -f "$zshrc" ]; then
        echo "[!] No .zshrc file found. Skipping aliases update."
        echo "-----------------------------"
        return
    fi

    # Backup .zshrc file
    cp "$zshrc" "$zshrc.bak"
    echo "[=] Backup of .zshrc created at $zshrc.bak"

    # Remove existing custom aliases section (between custom markers if they exist)
    sed -i '/# >>> CUSTOM ALIASES >>>/,/# <<< CUSTOM ALIASES <<</d' "$zshrc"

    # New aliases to insert (inside clear markers)
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

    # Append new aliases to .zshrc
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
    Creates a backup if an existing configuration is found.
    '

    echo "-----------------------------"
    echo "[*] Starting Powerlevel10k configuration setup."
    echo "-----------------------------"

    local p10k_url="https://pastebin.com/raw/U3g4iaPw"
    local target="$HOME/.p10k.zsh"

    # Check for internet connection
    if ! check_internet_connectivity; then
        echo "[!] No internet connection. Cannot download Powerlevel10k configuration."
        echo "-----------------------------"
        return 1
    fi

    # Backup existing .p10k.zsh if found
    if [ -f "$target" ]; then
        echo "[=] Existing .p10k.zsh found. Backing up to ${target}.bak"
        cp "$target" "${target}.bak"
    fi

    # Download .p10k.zsh from Pastebin
    echo "[+] Downloading .p10k.zsh from $p10k_url..."
    if curl -fsSL "$p10k_url" -o "$target"; then
        echo "[=] .p10k.zsh successfully downloaded and applied to $HOME/."
    else
        echo "[!] Failed to download .p10k.zsh. Check URL or connectivity."
    fi

    echo "-----------------------------"
}


main() {
    clear
    show_banner
    echo

    echo ">>> Starting post-installation script <<<"

    steps=(
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

    for step in "${steps[@]}"; do
        echo -e "\n[*] Running: $step..."
        if ! $step; then
            echo "[!] Error during $step. Check logs."
        fi
    done

    echo -e "\n>>> Post-installation script completed. <<<"
    exit 0
}


# Require root privileges
require_admin_rights
main
