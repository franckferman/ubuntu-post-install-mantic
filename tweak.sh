#!/bin/bash

: '
Script for post-installation setup on Ubuntu (developed on and for version 23.10 Mantic Minotaur).

Created By  : Franck FERMAN @franckferman
Created Date: 06/12/23
Version     : 1.0.1 (06/01/24)
'


require_admin_rights() {
    : '
    Ensure that the user has administrative privileges available for commands that will require them later in the script.
    '
    if ! sudo -v; then
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
    echo "-----------------------------"
    echo -e "[*] System update process initiated."
    echo "-----------------------------"

    if check_internet_connectivity; then
        echo -e "\n[*] Internet connectivity confirmed. Proceeding with system updates."

        # Update package information
        echo -e "\n[+] Running 'apt update'..."
        sudo apt update

        # Upgrade packages
        echo -e "\n[+] Running 'apt full-upgrade'..."
        sudo apt full-upgrade -y

        # Upgrade distribution
        echo -e "\n[+] Running 'apt dist-upgrade'..."
        sudo apt dist-upgrade -y
        
        # Clean up unused packages and dependencies
        echo -e "\n[+] Running 'apt autoclean'..."
        sudo apt autoclean -y

        echo -e "\n[+] Running 'apt autoremove'..."
        sudo apt autoremove -y

        echo -e "\n[*] System update process completed."
    else
        echo -e "\n[!] Skipping system update due to no internet connectivity."
    fi
    echo "-----------------------------"
}


configure_ufw() {
    : '
    Configure Uncomplicated Firewall (UFW) settings.
    '
    echo "-----------------------------"
    echo -e "[*] UFW configuration process initiated."
    echo "-----------------------------"

    ufw_status=$(sudo ufw status | grep "Status: active")

    # Enable UFW if it's not already active
    if [ -z "$ufw_status" ]; then
        echo -e "\n[+] Enabling UFW..."
        sudo ufw enable
    fi

    echo -e "\n[+] Setting up UFW default rules..."
    
    # Set default rules
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    echo -e "\n[*] UFW configuration completed."
    echo "-----------------------------"
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


configure_theme() {
    : '
    Configure the theme settings for the GNOME desktop environment.
    '
    echo "-----------------------------"
    echo "[*] Starting theme configuration."
    echo "-----------------------------"

    echo -e "\n[+] Changing color scheme to Dark..."
    set_gsetting "org.gnome.desktop.interface color-scheme" "'prefer-dark'"
    
    echo -e "\n[*] Listing available themes..."
    themes=$(ls -d /usr/share/themes/* | xargs -L 1 basename)

    if [ -z "$themes" ]; then
        echo -e "\n[!] No additional themes are installed. No theme change will be performed."
    else
        if echo "$themes" | grep -q "Yaru-red-dark"; then
            echo -e "\n[+] Applying Yaru-red-dark theme..."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Yaru-red-dark'"
        elif echo "$themes" | grep -q "Adwaita-dark"; then
            echo -e "\n[+] Applying Adwaita-dark theme..."
            set_gsetting "org.gnome.desktop.interface gtk-theme" "'Adwaita-dark'"
        else
            echo -e "\n[!] Neither Yaru-red-dark nor Adwaita-dark are available. No theme change will be performed."
        fi
    fi

    echo -e "\n[*] Setting desktop background."

    if gsettings writable org.gnome.desktop.background primary-color > /dev/null 2>&1; then
        echo -e "\n[+] Applying black as primary color for desktop background..."
        set_gsetting "org.gnome.desktop.background primary-color" "#000000"
    else
        echo -e "\n[!] Unable to set desktop background to black."
    fi

    if gsettings writable org.gnome.desktop.background secondary-color > /dev/null 2>&1; then
        echo -e "\n[+] Applying black as secondary color for desktop background..."
        set_gsetting "org.gnome.desktop.background secondary-color" "#000000"
    else
        echo -e "\n[!] Unable to set desktop background to black."
    fi

    if gsettings writable org.gnome.desktop.background picture-uri > /dev/null 2>&1; then
        echo -e "\n[+] Applying black as picture-uri for desktop background..."
        set_gsetting "org.gnome.desktop.background picture-uri" "''"
    else
        echo -e "\n[!] Unable to set desktop background (picture-uri) to black."
    fi

    if gsettings writable org.gnome.desktop.background picture-uri-dark > /dev/null 2>&1; then
        echo -e "\n[+] Applying black as picture-uri-dark for desktop background..."
        set_gsetting "org.gnome.desktop.background picture-uri-dark" "''"
    else
        echo -e "\n[!] Unable to set desktop background (picture-uri-dark) to black."
    fi

    echo -e "\n[*] Theme configuration process completed."
    echo "-----------------------------"
}


configure_ubuntu_desktop() {
    : '
    Configure the theme settings for the GNOME desktop environment.
    '
    echo "-----------------------------"
    echo "[*] Ubuntu desktop configuration."
    echo "-----------------------------"
    
    echo -e "\n[+] Setting new icons to appear at the top-left corner..."
    set_gsetting "org.gnome.shell.extensions.ding start-corner" "'top-left'"
    
    echo -e "\n[+] Disabling panel mode (Dash to Dock)..."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock extend-height" false
    
    echo -e "\n[+] Setting Dash to Dock icon size to 42..."
    set_gsetting "org.gnome.shell.extensions.dash-to-dock dash-max-icon-size" 42

    echo -e "\n[*] Ubuntu desktop configuration completed."
    echo "-----------------------------"
}


configure_privacy_settings() {
    : '
    Configure privacy settings.
    '
    echo "-----------------------------"
    echo "[*] Privacy configuration."
    echo "-----------------------------"

    echo -e "\n[+] Disabling connectivity checking..."
    busctl --system set-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager ConnectivityCheckEnabled "b" 0

    echo -e "\n[+] Configuring screen lock settings..."
    set_gsetting "org.gnome.desktop.screensaver lock-enabled" true
    set_gsetting "org.gnome.desktop.screensaver lock-delay" "uint32 0"
    set_gsetting "org.gnome.desktop.screensaver idle-activation-enabled" true
    set_gsetting "org.gnome.desktop.session idle-delay" "uint32 300"

    echo -e "\n[+] Disabling location services..."
    set_gsetting "org.gnome.system.location enabled" false

    echo -e "\n[+] Configuring file history settings..."
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" true
    set_gsetting "org.gnome.desktop.privacy recent-files-max-age" 1
    set_gsetting "org.gnome.desktop.privacy remember-recent-files" false

    echo -e "\n[+] Removing old trash and temporary files..."
    set_gsetting "org.gnome.desktop.privacy remove-old-trash-files" true
    set_gsetting "org.gnome.desktop.privacy remove-old-temp-files" true

    echo -e "\n[+] Setting age for considering files as old..."
    set_gsetting "org.gnome.desktop.privacy old-files-age" "uint32 0"

    echo -e "\n[+] Disabling the sending of technical problem reports..."
    set_gsetting "org.gnome.desktop.privacy report-technical-problems" false

    echo -e "\n[+] Hiding user identity..."
    set_gsetting "org.gnome.desktop.privacy hide-identity" true

    echo -e "\n[+] Disabling the sending of software usage stats..."
    set_gsetting "org.gnome.desktop.privacy send-software-usage-stats" false

    echo -e "\n[+] Disabling remote desktop services (RDP and VNC)..."
    set_gsetting "org.gnome.desktop.remote-desktop.rdp enable" false
    set_gsetting "org.gnome.desktop.remote-desktop.vnc enable" false
    
    echo -e "\n[+] Disabling remembering app usage..."
    set_gsetting "org.gnome.desktop.privacy remember-app-usage" false

    echo -e "\n[*] Privacy configuration completed."
    echo "-----------------------------"
}


configure_sound_settings() {
    : '
    Configure sound settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring sound settings."
    echo "-----------------------------"

    echo -e "\n[+] Muting system sound..."
    amixer set Master mute

    echo -e "\n[+] Turning off input volume..."
    amixer set Capture nocap

    echo -e "\n[*] Sound settings completed."
    echo "-----------------------------"
}


configure_power_perfs_settings() {
    : '
    Configure power and performance settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring power and performance settings."
    echo "-----------------------------"
    
    echo -e "\n[+] Setting power profile to performance..."
    set_gsetting "org.gnome.shell last-selected-power-profile" "'performance'"

    echo -e "\n[+] Enabling screen dimming..."
    set_gsetting "org.gnome.settings-daemon.plugins.power idle-dim" true

    echo -e "\n[+] Enabling automatic power saver on low battery..."
    set_gsetting "org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery" true
    
    echo -e "\n[+] Temporarily enabling suspend to set timeout settings..."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'suspend'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'suspend'"
    
    echo -e "\n[+] Setting logout delay to 2 hours..."
    set_gsetting "org.gnome.desktop.screensaver logout-delay" "uint32 7200"

    echo -e "\n[+] Setting sleep inactive timeout to 2 hours for both AC and battery..."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout" 7200
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout" 7200

    echo -e "\n[+] Disabling suspend after setting timeouts..."
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type" "'nothing'"
    set_gsetting "org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type" "'nothing'"

    echo -e "\n[*] Power and performance settings configuration completed."
    echo "-----------------------------"
}


configure_display_settings() {
    : '
    Configure display settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring interface and display settings."
    echo "-----------------------------"
    
    echo -e "\n[+] Enabling battery percentage display..."
    set_gsetting "org.gnome.desktop.interface show-battery-percentage" true

    echo -e "\n[+] Enabling Night Light from sunset to sunrise..."
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-enabled" true
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-schedule-automatic" true
    set_gsetting "org.gnome.settings-daemon.plugins.color night-light-temperature" "uint32 2700"

    echo -e "\n[*] Interface and display settings configuration completed."
    echo "-----------------------------"
}


configure_keyboard_settings() {
    : '
    Configure keyboard settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring keyboard layout."
    echo "-----------------------------"
    
    current_sources=$(gsettings get org.gnome.desktop.input-sources sources)

    if echo "$current_sources" | grep -q "('xkb', 'fr+azerty')"; then
        echo -e "\n[=] French (AZERTY) keyboard layout is already added."
    else
        echo -e "\n[+] Adding French (AZERTY) keyboard layout..."
        set_gsetting "org.gnome.desktop.input-sources mru-sources" "[('xkb', 'fr+azerty'), ('xkb', 'us')]"
        set_gsetting "org.gnome.desktop.input-sources sources" "[('xkb', 'us'), ('xkb', 'fr+azerty')]"
    fi

    echo -e "\n[*] Keyboard layout configuration completed."
    echo "-----------------------------"
}


configure_calendar_clock_settings() {
    : '
    Configure calendar and clock settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring calendar and clock settings."
    echo "-----------------------------"
    
    echo -e "\n[+] Enabling display of the weekday in the clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-weekday" true
    
    echo -e "\n[+] Enabling display of the date in the clock..."
    set_gsetting "org.gnome.desktop.interface clock-show-date" true
    
    echo -e "\n[+] Enabling display of week numbers in the calendar..."
    set_gsetting "org.gnome.desktop.calendar show-weekdate" true
    
    echo -e "\n[*] Calendar and clock settings configuration completed."
    echo "-----------------------------"
}


configure_file_manager_settings() {
    : '
    Configure file manager settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring file manager preferences."
    echo "-----------------------------"

    echo -e "\n[+] Setting directories to be sorted first..."
    set_gsetting "org.gtk.Settings.FileChooser sort-directories-first" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser sort-directories-first" true

    echo -e "\n[+] Enabling tree view in list view for directories..."
    set_gsetting "org.gnome.nautilus.list-view use-tree-view" true

    echo -e "\n[+] Enabling 'Create Link' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-create-link" true

    echo -e "\n[+] Enabling 'Delete Permanently' in context menu..."
    set_gsetting "org.gnome.nautilus.preferences show-delete-permanently" true

    echo -e "\n[+] Setting recursive search, image thumbnails, and directory item counts to 'always'..."
    set_gsetting "org.gnome.nautilus.preferences recursive-search" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-image-thumbnails" "'always'"
    set_gsetting "org.gnome.nautilus.preferences show-directory-item-counts" "'always'"

    echo -e "\n[+] Configuring grid view captions..."
    set_gsetting "org.gnome.nautilus.icon-view captions" "['detailed_type', 'size', 'permissions']"

    echo -e "\n[+] Enabling display of hidden files..."
    set_gsetting "org.gtk.Settings.FileChooser show-hidden" true
    set_gsetting "org.gtk.gtk4.Settings.FileChooser show-hidden" true
    set_gsetting "org.gnome.nautilus.preferences show-hidden-files" true

    echo -e "\n[*] File manager preferences configuration completed."
    echo "-----------------------------"
}


configure_gnome_terminal_settings() {
    : '
    Configure GNOME Terminal settings.
    '
    echo "-----------------------------"
    echo "[*] Configuring GNOME Terminal preferences."
    echo "-----------------------------"
    
    echo -e "\n[*] Retrieving the ID of the default terminal profile..."
    default_profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
    default_profile=${default_profile:1:-1}

    echo -e "\n[+] Renaming the default profile to 'root'..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/visible-name "'root'"

    echo -e "\n[+] Deactivate basic system theme..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-colors false

    echo -e "\n[+] Configuring the profile colors..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/foreground-color "'rgb(208,207,204)'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/background-color "'rgb(23,20,33)'"

    echo -e "\n[+] Configuring transparency..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/use-theme-transparency true

    echo -e "\n[+] Configuring the built-in color scheme..."
    dconf write /org/gnome/terminal/legacy/profiles:/:$default_profile/palette "['rgb(23,20,33)', 'rgb(192,28,40)', 'rgb(38,162,105)', 'rgb(162,115,76)', 'rgb(18,72,139)', 'rgb(163,71,186)', 'rgb(42,161,179)', 'rgb(208,207,204)', 'rgb(94,92,100)', 'rgb(246,97,81)', 'rgb(51,209,122)', 'rgb(233,173,12)', 'rgb(42,123,222)', 'rgb(192,97,203)', 'rgb(51,199,222)', 'rgb(255,255,255)']"

    echo -e "\n[*] GNOME Terminal preferences configuration completed."
    echo "-----------------------------"
}


configure_gnome_shell_text_editor_settings() {
    : '
    Configure GNOME Shell favorites and Text Editor settings.
    ' 
    echo "-----------------------------"
    echo "[*] Configuring GNOME Shell favorites and Text Editor preferences."
    echo "-----------------------------"

    echo -e "\n[+] Setting favorite applications..."
    set_gsetting "org.gnome.shell favorite-apps" "['firefox_firefox.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop']"

    echo -e "\n[+] Enabling line numbers in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor show-line-numbers" true

    echo -e "\n[+] Enabling right margin in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor show-right-margin" true

    echo -e "\n[+] Setting style scheme to 'dark' for Text Editor..."
    set_gsetting "org.gnome.TextEditor style-variant" "'dark'"

    echo -e "\n[+] Setting style scheme to 'classic-dark' for Text Editor..."
    set_gsetting "org.gnome.TextEditor style-scheme" "'classic-dark'"

    echo -e "\n[+] Enabling grid pattern and highlighting current line in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor highlight-current-line" true
    set_gsetting "org.gnome.TextEditor show-grid" true

    echo -e "\n[+] Disabling spellcheck in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor spellcheck" false

    echo -e "\n[+] Enabling text wrapping in GNOME Text Editor..."
    set_gsetting "org.gnome.TextEditor wrap-text" true

    echo -e "\n[*] GNOME Shell favorites and Text Editor preferences configuration completed."
    echo "-----------------------------"
}


configure_system_settings() {
    : '
    Configure system settings.
    '
    echo "-----------------------------"
    echo "[*] Starting system settings configuration."
    echo -e "-----------------------------\n"
    configure_theme
    echo
    configure_ubuntu_desktop
    echo
    configure_privacy_settings
    echo
    configure_sound_settings
    echo
    configure_power_perfs_settings
    echo
    configure_display_settings
    echo
    configure_keyboard_settings
    echo
    configure_calendar_clock_settings
    echo
    configure_file_manager_settings
    echo
    configure_gnome_terminal_settings
    echo
    configure_gnome_shell_text_editor_settings
    echo -e "\n[*] All system settings configurations completed."
    echo "-----------------------------"
}


disable_service() {
    : '
    Disable a specified systemd service.

    Args:
        service (str): The name of the service to disable.
    '
    local service=$1
    echo -e "\n[+] Ensure $service is not enabled..."
    if sudo systemctl is-enabled "$service" > /dev/null 2>&1 ; then
        sudo systemctl disable "$service"
    fi
}


remove_package() {
    : '
    Remove a specified package using apt.

    Args:
        package (str): The name of the package to remove.
    '
    local package=$1
    echo -e "\n[+] Ensure $package is not installed..."
    if sudo dpkg -s "$package" > /dev/null 2>&1 ; then
        sudo apt remove -y "$package"
    fi
}


configure_hardening() {
    : '
    Hardens the system.
    '
    echo "-----------------------------"
    echo "[*] Starting hardening configuration."
    echo "-----------------------------"
    
    echo -e "\n[+] Disable root account..."
    sudo passwd -l root
    # use `sudo passwd -l root` if you need to re-enable the account.
    
    if check_internet_connectivity; then
        echo -e "\n[*] Internet connectivity confirmed. Proceeding with installation of security packages."
        echo -e "\n[+] Installing USBGuard..."
        sudo apt install usbguard -y
    else
        echo -e "\n[!] Skipping installation of security packages due to no internet connectivity."
    fi

    # Disable various services
    for service in slapd nfs-server rpcbind bind9 vsftpd apache2 dovecot exim cyrus-imap smbd squid snmpd postfix sendmail rsync nis; do
        disable_service "$service"
    done

    # Remove various packages
    for package in nis rsh-client rsh-redone-client talk telnet ldap-utils; do
        remove_package "$package"
    done

    echo -e "\n[*] All hardening configuration completed..."
    echo "-----------------------------"
}


install_deb_from_url() {
    : '
    Download and install a .deb package.
    
    Args:
        url (str): URL to the .deb file.
    '
    local url=$1

    if check_internet_connectivity; then
        echo -e "[*] Internet connectivity confirmed. Proceeding with downloading .deb package from $url.\n"

        if curl -LO "$url"; then
            local deb_name=$(basename "$url")

            echo -e "\nInstalling $deb_name...\n"
            if sudo dpkg -i "$deb_name"; then
                echo -e "\n$deb_name installed successfully."
            else
                echo "Installation failed! Attempting to fix dependencies..."
                sudo apt install -f
            fi

            echo -e "\nCleaning up..."
            rm "$deb_name"
            echo -e "Temporary file removed."
        else
            echo -e "\nDownload failed!"
        fi
    else
        echo -e "\n[!] Skipping downloading .deb package from $url due to no internet connectivity."
    fi
}


install_basic_apps() {
    : '
    Installing basic applications.
    '
    echo "-----------------------------"
    echo "[*] Basic application installation."
    echo -e "-----------------------------\n"
    
    sudo apt install nala zulucrypt-gui keepassxc vim git curl tmux bat lsd mat2 rssguard python3 python3-pip python3-venv gnome-software gnome-shell-extension-manager gnome-tweaks hicolor-icon-theme gnome-menus desktop-file-utils -y
    # gnome-maps gnome-weather gnome-calendar gnome-clocks 0ad junior-*
    echo
    sudo snap refresh
    echo
    sudo snap install xmind --classic
    sudo snap install obsidian --classic
    echo
    install_deb_from_url "https://mullvad.net/download/app/deb/latest"
    echo -e "\n[*] Basic application installation completed."
    echo "-----------------------------"
}


main() {
    clear
    show_banner
    echo
    perform_system_update
    echo
    configure_ufw
    echo
    configure_system_settings
    echo
    configure_hardening
    echo
    install_basic_apps
    exit 0
}


require_admin_rights
main
