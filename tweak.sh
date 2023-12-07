#!/bin/bash

: '
Script for post-installation setup on Ubuntu (developed on and for version 23.10 Mantic Minotaur).

Created By  : Franck FERMAN @franckferman
Created Date: 06/12/23
Version     : 1.0.0 (06/12/23)
'


check_admin_rights() {
    : '
    Check if the script is run with root privileges.
    '
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Please run the script as root (using sudo)."
        exit 1
    fi
}


require_admin_rights() {
    : '
    Ensure that the user has administrative privileges available for commands that will require them later in the script.
    '
    if ! sudo -v; then
        echo
        echo "This script requires administrative privileges. Please rerun it with a user with sudo privileges."
        exit 1
    fi

    while true; do 
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
}


show_banner() {
    : '
    Display a graphical banner.
    '
    cat << "EOF"
     ,-O
    O(_)) Ubuntu post-install script
     `-O 
EOF
}


check_internet_connectivity() {
    : '
    Check the Internet connectivity by pinging a well-known server.
    '
    ping -c 2 -W 5 1.1.1.1 > /dev/null 2>&1
    return $?
}


perform_system_update() {
    : '
    Perform a full system update if internet connectivity is available.
    '
    echo
    echo "[*] System update process..."
    if check_internet_connectivity; then
        echo
        echo "[*] Internet connectivity confirmed. Proceeding with system updates."
        echo

        echo "[*] Running 'apt update'..."
        echo
        sudo apt update

        echo
        echo "[*] Running 'apt full-upgrade'..."
        echo
        sudo apt full-upgrade -y

        echo
        echo "[*] Running 'apt dist-upgrade'..."
        echo
        sudo apt dist-upgrade -y
        
        echo
        echo "[*] Running 'apt autoclean'..."
        echo
        sudo apt autoclean -y

        echo
        echo "[*] Running 'apt autoremove'..."
        echo
        sudo apt autoremove -y

        echo
        echo "[*] System update process completed."
    else
        echo
        echo "[!] Skipping system update due to no internet connectivity."
    fi
}


configure_ufw() {
    : '
    Configure Uncomplicated Firewall (UFW) settings.
    '
    echo
    echo "[*] UFW configuration..."
    ufw_status=$(sudo ufw status | grep "Status: active")

    if [ -z "$ufw_status" ]; then
        echo
        echo "[*] Enabling UFW..."
        sudo ufw enable
    fi

    echo
    echo "[*] Setting default UFW policies..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    echo
    echo "[*] UFW configuration completed."
}


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

    current_value=$(gsettings get $key 2> /dev/null)

    if [ $? -ne 0 ]; then
        echo "[!] The key $key does not exist."
        return
    fi

    if [ "$current_value" != "$value" ]; then
        echo "[+] Setting $key to $value."
        gsettings set $key $value
    else
        echo "[=] $key is already set to $value."
    fi
}


configure_theme() {
    : '
    Configure the theme settings for the GNOME desktop environment.
    '
    echo
    echo "[*] Starting theme configuration..."
    echo
    
    echo "[*] Changing color scheme to Dark..."
    set_gsetting "org.gnome.desktop.interface color-scheme" "'prefer-dark'"
    
    echo
    echo "[*] Listing available themes..."
    themes=$(ls -d /usr/share/themes/* | xargs -L 1 basename)

    if [ -z "$themes" ]; then
        echo "[!] No additional themes are installed. No theme change will be performed."
    else
        if echo "$themes" | grep -q "Yaru-red-dark"; then
            echo "[+] Applying Yaru-red-dark theme..."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Yaru-red-dark'"
        elif echo "$themes" | grep -q "Adwaita-dark"; then
            echo "[+] Applying Adwaita-dark theme..."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Adwaita-dark'"
        else
            echo "[!] Neither Yaru-red-dark nor Adwaita-dark are available. No theme change will be performed."
        fi
    fi

    echo
    echo "[+] Setting desktop background to black..."
    if gsettings writable org.gnome.desktop.background primary-color > /dev/null 2>&1; then
        echo "[+] Applying black as primary color for desktop background..."
        set_gsetting "org.gnome.desktop.background primary-color" "'#000000'"
    elif gsettings writable org.gnome.desktop.background picture-uri-dark > /dev/null 2>&1; then
        echo "[+] Applying black as picture-uri-dark for desktop background..."
        set_gsetting "org.gnome.desktop.background picture-uri-dark" "''"
    else
        echo "[!] Unable to set desktop background to black."
    fi

    echo
    echo "[*] Theme configuration process completed..."
}


configure_ubuntu_desktop() {
    : '
    Configure the theme settings for the GNOME desktop environment.
    '
    echo
    echo "[*] Ubuntu desktop configuration..."
    echo
    
    echo "[+] Setting new icons to appear at the top-left corner..."
    set_gsetting "org.gnome.shell.extensions.ding start-corner" "'top-left'"
    
    echo "[+] Disabling panel mode (Dash to Dock)..."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock extend-height" false
    
    echo "[+] Setting Dash to Dock icon size to 42..."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock dash-max-icon-size" 42

    echo
    echo "[*] Ubuntu desktop configuration completed."
}


configure_privacy_settings() {
    : '
    Configure privacy settings.
    '
    echo "[*] Privacy configuration..."
    echo

    echo "[+] Disabling connectivity checking..."
    busctl --system set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled "b" 0

    echo "[+] Configuring screen lock settings..."
    set_gsetting "org.gnome.desktop.screensaver lock-enabled" true
    set_gsetting "org.gnome.desktop.screensaver lock-delay" "uint32 0"
    set_gsetting "org.gnome.desktop.screensaver idle-activation-enabled" true
    set_gsetting "org.gnome.desktop.session idle-delay" "uint32 300"

    echo "[+] Disabling location services..."
    set_gsetting "org.gnome.system.location enabled" false

    echo "[+] Configuring file history settings..."
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" true
    set_gsetting "org.gnome.desktop.privacy recent-files-max-age" 1
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" false

    echo "[+] Removing old trash and temporary files..."
    set_gsetting "org.gnome.desktop.privacy remove-old-trash-files" true
    set_gsetting "org.gnome.desktop.privacy remove-old-temp-files" true

    echo "[+] Setting age for considering files as old..."
    set_gsetting "org.gnome.desktop.privacy old-files-age" "uint32 0"

    echo "[+] Disabling the sending of technical problem reports..."
    set_gsetting "org.gnome.desktop.privacy report-technical-problems" false

    echo "[+] Hiding user identity..."
    set_gsetting "org.gnome.desktop.privacy hide-identity" true

    echo "[+] Disabling the sending of software usage stats..."
    set_gsetting "org.gnome.desktop.privacy send-software-usage-stats" false

    echo "[+] Disabling remote desktop services (RDP and VNC)..."
    set_gsetting "org.gnome.desktop.remote-desktop.rdp enable" false
    set_gsetting "org.gnome.desktop.remote-desktop.vnc enable" false
    
    echo "[+] Disabling remembering app usage..."
    set_gsetting "org.gnome.desktop.privacy remember-app-usage" false

    echo
    echo "[*] Privacy configuration completed."
}


configure_sound_settings() {
    : '
    Configure sound settings.
    '
    echo
    echo "[*] Configuring sound settings..."
    echo

    echo "[+] Muting system sound..."
    echo
    amixer set Master mute

    echo
    echo "[+] Turning off input volume..."
    echo
    amixer set Capture nocap

    echo
    echo "[*] Sound settings completed..."
}


configure_power_perfs_settings() {
    : '
    Configure power and performance settings.
    '
    echo
    echo "[*] Configuring power and performance settings..."
    echo
    
    echo "[+] Setting power profile to performance..."
    set_gsetting "org.gnome.shell last-selected-power-profile" "'performance'"

    echo "[+] Enabling screen dimming..."
    set_gsetting "org.gnome.settings-daemon.plugins.power idle-dim" true

    echo "[+] Enabling automatic power saver on low battery..."
    set_gsetting "org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery" true
    
    echo "[+] Temporarily enabling suspend to set timeout settings..."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'suspend'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'suspend'"
    
    echo "[+] Setting logout delay to 2 hours..."
    set_gsetting "org.gnome.desktop.screensaver logout-delay" "uint32 7200"

    echo "[+] Setting sleep inactive timeout to 2 hours for both AC and battery..."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout" 7200
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout" 7200

    echo "[+] Disabling suspend after setting timeouts..."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'nothing'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'nothing'"

    echo
    echo "[*] Power and performance settings configuration completed."
}


configure_display_settings() {
    : '
    Configure display settings.
    '
    echo
    echo "[*] Configuring interface and display settings..."
    echo
    
    echo "[+] Enabling battery percentage display..."
    set_gsetting "org.gnome.desktop.interface show-battery-percentage" true

    echo "[+] Enabling Night Light from sunset to sunrise..."
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-enabled" true
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-schedule-automatic" true
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-temperature" "uint32 2700"

    echo
    echo "[*] Interface and display settings configuration completed."
}


configure_keyboard_settings() {
    : '
    Configure keyboard settings.
    '
    echo
    echo "[*] Configuring keyboard layout..."
    echo
    
    current_sources=$(gsettings get org.gnome.desktop.input-sources sources)

    if echo "$current_sources" | grep -q "('xkb', 'fr+azerty')"; then
        echo "[=] French (AZERTY) keyboard layout is already added."
    else
        echo "[+] Adding French (AZERTY) keyboard layout..."
        set_gsetting "org.gnome.desktop.input-sources mru-sources" "[('xkb', 'fr+azerty'), ('xkb', 'us')]"
        set_gsetting "org.gnome.desktop.input-sources sources" "[('xkb', 'us'), ('xkb', 'fr+azerty')]"
    fi

    echo
    echo "[*] Keyboard layout configuration completed."
}


configure_calendar_clock_settings() {
    : '
    Configure calendar and clock settings.
    '
    echo
    echo "[*] Configuring calendar and clock settings..."
    echo
    
    echo "[+] Enabling display of the weekday in the clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-weekday" true
    
    echo "[+] Enabling display of the date in the clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-date" true
    
    echo "[+] Enabling display of week numbers in the calendar..."
    set_gsetting "org.gnome.desktop.calendar show-weekdate" true
    
    echo
    echo "[*] Calendar and clock settings configuration completed."
}


configure_file_manager_settings() {
    : '
    Configure file manager settings.
    '
    echo
    echo "[*] Configuring file manager preferences..."
    echo

    echo "[+] Setting directories to be sorted first..."
    set_gsetting "org.gtk.Settings.FileChooser sort-directories-first" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser sort-directories-first" true

    echo "[+] Enabling tree view in list view for directories..."
    set_gsetting "org.gnome.nautilus.list-view use-tree-view" true

    echo "[+] Enabling 'Create Link' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-create-link" true

    echo "[+] Enabling 'Delete Permanently' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-delete-permanently" true

    echo "[+] Setting recursive search, image thumbnails, and directory item counts to 'always'..."
    set_gsetting "org.gnome.nautilus.preferences recursive-search" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-image-thumbnails" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-directory-item-counts" "'always'"

    echo "[+] Configuring grid view captions..."
    set_gsetting "org.gnome.nautilus.icon-view captions" "['detailed_type', 'size', 'permissions']"

    echo "[+] Enabling display of hidden files..."
    set_gsetting "org.gtk.Settings.FileChooser show-hidden" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser show-hidden" true
    set_gsetting "org.gnome.nautilus.preferences show-hidden-files" true

    echo
    echo "[*] File manager preferences configuration completed."
}


configure_gnome_terminal_settings() {
    : '
    Configure GNOME Terminal settings.
    ' 
    echo
    echo "[*] Configuring GNOME Terminal preferences..."
    echo
    
    echo "[*] Retrieving the ID of the default terminal profile..."
    default_profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
    default_profile=${default_profile:1:-1}

    echo "[+] Renaming the default profile to 'root'..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/visible-name "'root'"

    echo "[+] Configuring the profile colors..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/foreground-color "'rgb(208,207,204)'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/background-color "'rgb(23,20,33)'"

    echo "[+] Configuring transparency..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-transparency true

    echo "[+] Configuring the built-in color scheme..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/palette "['rgb(23,20,33)', 'rgb(192,28,40)', 'rgb(38,162,105)', 'rgb(162,115,76)', 'rgb(18,72,139)', 'rgb(163,71,186)', 'rgb(42,161,179)', 'rgb(208,207,204)', 'rgb(94,92,100)', 'rgb(246,97,81)', 'rgb(51,209,122)', 'rgb(233,173,12)', 'rgb(42,123,222)', 'rgb(192,97,203)', 'rgb(51,199,222)', 'rgb(255,255,255)']"

    echo
    echo "[*] GNOME Terminal preferences configuration completed."
}


configure_gnome_shell_text_editor_settings() {
    : '
    Configure GNOME Shell favorites and Text Editor settings.
    ' 
    echo
    echo "[*] Configuring GNOME Shell favorites and Text Editor preferences..."
    echo

    echo "[+] Setting favorite applications..."
    set_gsetting "org.gnome.shell favorite-apps" "['firefox_firefox.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop']"

    echo "[+] Enabling line numbers in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor show-line-numbers" true

    echo "[+] Enabling right margin in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor show-right-margin" true

    echo "[+] Setting style scheme to 'dark' for Text Editor..."
    set_gsetting "org.gnome.TextEditor style-variant" "'dark'"

    echo "[+] Setting style scheme to 'classic-dark' for Text Editor..."
    set_gsetting "org.gnome.TextEditor style-scheme" "'classic-dark'"

    echo "[+] Enabling grid pattern and highlighting current line in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor highlight-current-line" true
    set_gsetting "org.gnome.TextEditor show-grid" true

    echo "[+] Disabling spellcheck in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor spellcheck" false

    echo "[+] Enabling text wrapping in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor wrap-text" true

    echo
    echo "[*] GNOME Shell favorites and Text Editor preferences configuration completed."
}


configure_system_settings() {
    : '
    Configure system settings.
    '
    echo
    echo "[*] Starting system settings configuration..."
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
    echo
    echo "[*] All system settings configurations completed..."
}

configure_hardening() {
    : '
    Hardens the system.
    '
    echo
    echo "[*] Starting hardening configuration..."
    echo
    
    echo "[+] Disable root account..."
    sudo passwd -l root
    # use `sudo passwd -l root` if you need to re-enable the account.
    
    echo
    echo "[+] Installing USBGuard..."
    sudo apt install usbguard -y
    
    echo
    echo "[*] All hardening configuration completed..."
}


install_basic_apps() {
    : '
    Installing basic applications.
    '
    echo
    echo "[*] Basic application installation..."
    echo
    
    sudo apt install nala zulucrypt-gui keepassxc vim git curl tmux bat lsd mat2 rssguard python3 python3-pip python3-venv gnome-software sudo apt install gnome-software gnome-maps gnome-weather gnome-calendar gnome-clocks gnome-shell-extension-manager gnome-tweaks -y
    # junior-art, junior-config, junior-doc, junior-education, junior-games-adventure, junior-games-arcade, junior-games-card, junior-games-gl, junior-games-net, junior-games-puzzle, junior-games-sim, junior-games-text, junior-internet, junior-math, junior-programming, junior-sound, junior-system, junior-tasks, junior-toys, junior-typing, junior-video, junior-writing
    # 0ad
    
    echo
    echo "[*] Basic application installation completed..."
}


main() {
    clear
    show_banner
    perform_system_update
    configure_ufw
    configure_system_settings
    configure_hardening
    install_basic_apps
    exit 0
}


# check_admin_rights
require_admin_rights
main

