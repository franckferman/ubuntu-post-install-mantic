#!/bin/bash

: '
Script for post-installation setup on Ubuntu (developed on and for version 23.10 Mantic Minotaur).

Created By  : Franck FERMAN @franckferman
Created Date: 06/12/23
Version     : 1.0.2 (07/01/24)
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
    
    sudo apt install nala zulucrypt-gui keepassxc vim git curl tmux lsd mat2 rssguard python3 python3-pip python3-venv zsh taskwarrior net-tools
    # gnome-software gnome-shell-extension-manager gnome-tweaks hicolor-icon-theme gnome-menus desktop-file-utils gnome-maps gnome-weather gnome-calendar gnome-clocks 
    # 0ad junior-*
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


manage_firefox_profiles() {
    : '
    Manages Firefox profiles by finding the profiles.ini file,
    deleting existing profiles, creating a new profile named "root",
    launching Firefox with this profile, waiting for 5 seconds, and then closing it.
    After closing Firefox, it copies user.js into the newly created root profile if it exists.
    '
    echo "-----------------------------"
    echo "[*] Starting Firefox profile management."
    echo "-----------------------------"

    local profiles_ini
    profiles_ini=$(find ~ -name 'profiles.ini' -print 2>/dev/null | head -n 1)
    
    if [[ -z "$profiles_ini" ]]; then
        echo "No profiles.ini file found."
        echo -e "-----------------------------\n"
    else
        local profile_dir
        profile_dir=$(dirname "$profiles_ini")

        echo "Profile directory found: $profile_dir"

        # Delete old profiles
        echo "Deleting old profiles..."
        find "$profile_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} \;

        # Create a new profile named 'root'
        echo "Creating 'root' profile..."
        firefox -CreateProfile "root $profile_dir/root" >/dev/null 2>&1

        # Launch Firefox with the 'root' profile, wait for 5 seconds, and close
        echo "Launching Firefox with 'root' profile..."
        firefox -P "root" &
        local firefox_pid=$!
        sleep 5

        echo "Closing Firefox..."
        kill "$firefox_pid"

        # Copy user.js into the new root profile if it exists
        local user_js_path="./assets/conf/user.js"
        if [[ -f "$user_js_path" ]]; then
            echo "Copying user.js into the root profile..."
            cp "$user_js_path" "$profile_dir/root/"
        else
            echo "user.js not found. No file copied."
        fi
    fi

    echo -e "\n[*] Firefox profile management completed."
    echo "-----------------------------"
}


install_spacevim() {
    : '
    Installs SpaceVim, a community-driven modular vim distribution.
    '

    echo "-----------------------------"
    echo "[*] Starting SpaceVim installation."
    echo "-----------------------------"

    # Check for internet connectivity
    if check_internet_connectivity; then
        echo -e "\n[*] Internet connectivity confirmed. Proceeding with SpaceVim installation."

        # Check if curl is installed
        if ! command -v curl &> /dev/null; then
            echo "curl is required but not installed. Aborting."
        else
            # Download and execute the SpaceVim install script
            echo "Downloading and running the SpaceVim install script..."
            if curl -sLf https://spacevim.org/install.sh | bash; then
                echo -e "\n[*] SpaceVim installation completed successfully."
            else
                echo -e "\n[!] SpaceVim installation failed."
            fi
        fi
    else
        echo -e "\n[!] Skipping SpaceVim installation due to no internet connectivity."
    fi

    echo "-----------------------------"
}


install_nerd_fonts() {
    : '
    Checks if the Nerd Fonts directory exists and installs the fonts inside.
    '

    echo "-----------------------------"
    echo "[*] Starting Nerd Fonts installation."
    echo "-----------------------------"

    local font_dir="assets/fonts/NerdFonts/"

    # Check if the Nerd Fonts directory exists
    if [ -d "$font_dir" ]; then
        echo "Nerd Fonts directory found. Installing fonts..."

        # Find and install each font in the directory
        local font
        for font in "$font_dir"*.ttf; do
            echo "Installing font: $font"
            cp "$font" ~/.local/share/fonts/ || echo "Failed to install $font."
        done

        # Update font cache
        echo "Updating font cache..."
        fc-cache -f
    else
        echo "Nerd Fonts directory not found. Skipping font installation."
    fi

    echo "Nerd Fonts installation process completed."
    echo "-----------------------------"
}


install_ohmyzsh() {
    : '
    Installs Oh My Zsh, an open source, community-driven framework for managing your zsh configuration.
    '

    echo "-----------------------------"
    echo "[*] Starting Oh My Zsh installation."
    echo "-----------------------------"

    # Check for internet connectivity
    if check_internet_connectivity; then
        echo -e "\n[*] Internet connectivity confirmed. Proceeding with Oh My Zsh installation."

        # Check if zsh is installed
        if ! command -v zsh &> /dev/null; then
            echo "zsh is required but not installed. Aborting."
        else
            # Install Oh My Zsh
            echo "Downloading and running the Oh My Zsh install script..."
            if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
                echo -e "\n[*] Oh My Zsh installation completed successfully."

                # Clear the history
                echo "Clearing bash history..."
                history -c
                rm ~/.bash_history

                # Change the default shell to zsh
                echo "Changing the default shell to zsh..."
                sudo chsh -s /usr/bin/zsh

                echo "Default shell changed to zsh."
            else
                echo -e "\n[!] Oh My Zsh installation failed."
            fi
        fi
    else
        echo -e "\n[!] Skipping Oh My Zsh installation due to no internet connectivity."
    fi

    echo "-----------------------------"
}

custom_zsh() {
    : '
    Customizes Zsh with the Powerlevel10k theme and various Zsh plugins.
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh customization."
    echo "-----------------------------"

    # Save the current shell
    local original_shell
    original_shell=$(echo "$SHELL")

    # Check current shell and switch to Zsh if not already using it
    local switch_to_original_shell=false
    if [ -n "$ZSH_VERSION" ]; then
        echo "Already using Zsh."
    else
        echo "Switching to Zsh..."
        if sudo chsh -s "$(which zsh)"; then
            switch_to_original_shell=true
            exec zsh
        else
            echo "Failed to switch to Zsh. Continuing with the current shell."
        fi
    fi

    # Check internet connectivity
    if ! check_internet_connectivity; then
        echo "Internet connectivity is required. Please check your connection."
    else
        # Install Powerlevel10k theme
        echo "Installing Powerlevel10k theme..."
        git clone https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" || echo "Failed to clone Powerlevel10k."

        # Update .zshrc for Powerlevel10k theme
        echo "Setting ZSH_THEME to 'powerlevel10k/powerlevel10k' in .zshrc..."
        sed -i 's/^ZSH_THEME="[^"]*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc

        # Install Zsh plugins
        echo "Installing Zsh plugins..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" || echo "Failed to clone zsh-autosuggestions."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" || echo "Failed to clone zsh-syntax-highlighting."
        git clone https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-completions" || echo "Failed to clone zsh-completions."

        # Update .zshrc for plugins
        echo "Adding plugins to .zshrc..."
        sed -i 's/plugins=(\(.*\))/plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)/' ~/.zshrc
    fi

    # After successful installation, switch back if we changed the shell
    if $switch_to_original_shell; then
        sudo chsh -s "$original_shell"
        echo "Switched back to the original shell."
    fi

    echo "Zsh customization completed."
    echo "-----------------------------"
}


update_zsh_plugins() {
    : '
    Updates the Zsh configuration with a new set of plugins.
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh plugins update."
    echo "-----------------------------"

    local zshrc="$HOME/.zshrc"

    # List of plugins to add
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

    # Check and add existing plugins
    [[ $(grep "zsh-autosuggestions" "$zshrc") ]] && plugins_to_add+=(zsh-autosuggestions)
    [[ $(grep "zsh-syntax-highlighting" "$zshrc") ]] && plugins_to_add+=(zsh-syntax-highlighting)
    [[ $(grep "zsh-completions" "$zshrc") ]] && plugins_to_add+=(zsh-completions)

    # Convert the array into a formatted string
    local formatted_plugins
    formatted_plugins=$(printf "  %s\n" "${plugins_to_add[@]}")

    # Backup .zshrc file
    cp "$zshrc" "$zshrc.bak"

    # Replace the plugins line in .zshrc
    sed -i "/^plugins=(/c\\plugins=(\n${formatted_plugins})" "$zshrc"

    echo "Zsh plugins updated successfully."
    echo "-----------------------------"
}


update_zsh_aliases() {
    : '
    Updates the Zsh configuration with a new set of custom aliases.
    '

    echo "-----------------------------"
    echo "[*] Starting Zsh aliases update."
    echo "-----------------------------"

    local zshrc="$HOME/.zshrc"

    # Backup .zshrc file
    cp "$zshrc" "$zshrc.bak"

    # Remove existing aliases section
    sed -i '/# Example aliases/,/# alias ohmyzsh="mate ~\/.oh-my-zsh"/d' "$zshrc"

    # New aliases to add
    local new_aliases=$(cat << 'EOF'
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
alias logs=history
alias mkdir='mkdir -p'
alias mountedinfo='df -hT'
alias open='xdg-open'
alias openports='netstat -nape --inet'
EOF
)

    # Append new aliases to .zshrc
    echo "$new_aliases" >> "$zshrc"

    echo "Zsh aliases updated successfully."
    echo "-----------------------------"
}


copy_p10k_config() {
    : '
    Copies the .p10k.zsh configuration file to the user home directory if it exists.
    '

    echo "-----------------------------"
    echo "[*] Checking for .p10k.zsh configuration file."
    echo "-----------------------------"

    local p10k_config="assets/conf/.p10k.zsh"

    # Check if the .p10k.zsh file exists
    if [ -f "$p10k_config" ]; then
        echo "Found .p10k.zsh. Copying to home directory..."
        cp "$p10k_config" ~/

        echo ".p10k.zsh copied successfully."
    else
        echo ".p10k.zsh not found. No file copied."
    fi

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
    echo
    manage_firefox_profiles
    echo
    install_spacevim
    echo
    install_nerd_fonts
    echo
    install_ohmyzsh
    echo
    custom_zsh
    echo
    update_zsh_plugins
    echo
    update_zsh_aliases
    echo
    copy_p10k_config
    exit 0
}


require_admin_rights
main
