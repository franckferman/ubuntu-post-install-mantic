<div id="top" align="center">

<!-- Shields Header -->
[![Contributors][contributors-shield]](https://github.com/franckferman/ubuntu-post-install/graphs/contributors)
[![Forks][forks-shield]](https://github.com/franckferman/ubuntu-post-install/network/members)
[![Stargazers][stars-shield]](https://github.com/franckferman/ubuntu-post-install/stargazers)
[![Issues][issues-shield]](https://github.com/franckferman/ubuntu-post-install/issues)
[![License][license-shield]](https://github.com/franckferman/ubuntu-post-install/blob/stable/LICENSE)

<!-- Title & Tagline -->
<h3 align="center">🐧 ubuntu-post-install</h3>
<p align="center">
    <em>Automated post-installation script for Ubuntu.</em>
    <br>
     Configure, harden, and optimize your system in one command.
</p>

</div>

## 📜 Table of Contents

<details open>
  <summary><strong>Click to collapse/expand</strong></summary>
  <ol>
    <li><a href="#-about">📖 About</a></li>
    <li><a href="#-installation">🛠️ Installation</a></li>
    <li><a href="#-usage">🎮 Usage</a></li>
    <li><a href="#-contributing">🤝 Contributing</a></li>
    <li><a href="#-star-evolution">🌠 Star Evolution</a></li>
    <li><a href="#-license">📜 License</a></li>
    <li><a href="#-contact">📞 Contact</a></li>
  </ol>
</details>

## 📖 About

This is a post-installation automation script for Ubuntu, designed to apply my complete system setup in one shot — from hardening to theming, including essential software, configurations, and privacy fixes.

> ⚙️ **Note**: This script is still under **active development** — far from a final version. Many features and improvements are still to come. Use it as a solid starting point, but expect updates and expansions.

Originally developed on Ubuntu 23.10 (Mantic Minotaur), but also tested and running smoothly on Ubuntu 24.04 (Noble Numbat).

Since it relies on standard tools and GNOME GSettings, it should work on other Ubuntu or GNOME-based distributions — though official support and validation is currently for Ubuntu 23.10.

> ⚠️ If you use this script on other versions, feel free to report issues or submit corrections via pull requests.

### 💡 Main goal

- ⚙️ Fast, secure, and reproducible setup — focused on privacy, performance, minimalism.
- 🌑 Dark-themed, optimized GNOME desktop experience.
- 🔐 System hardening for personal/pro use: USBGuard, disable unused services, clean legacy tools.
- 🛠️ Full environment automation:
  - ZSH + Oh My Zsh + Powerlevel10k.
  - Essential plugins and aliases.
  - GNOME and terminal customizations.

➡️ A fully optimized, secured, and ready-to-use Ubuntu system — with zero manual intervention.

Because I'm detail-oriented (some might say perfectionist, I prefer carefully crafted), everything must be set exactly as I want: Appearance, privacy, usability, security, and performance.

> I built this script to ensure a reproducible, optimized, and efficient system, every time.

### 📦 Features

- 📦 System & Security Setup
  - ✅ System update & upgrade (apt update, full-upgrade, dist-upgrade, autoclean, autoremove)
  - ✅ Firewall (UFW) activation & configuration
- 📦 System Configuration (GNOME & Ubuntu Desktop)
  - ✅ Theme configuration (Dark mode, GTK theme preference)
  - ✅ Desktop appearance settings (background, color scheme)
  - ✅ Dash-to-Dock and icons behavior (position, size, mode)
  - ✅ Privacy settings (disable telemetry, connectivity checks, location, file history, trash auto-clean)
  - ✅ Screen lock & idle settings (delay, lock-on-idle)
  - ✅ Sound settings (mute system sound and input by default)
  - ✅ Power & performance optimization
    - Power profile to "performance"
    - Disable sleep after timeout
    - Set idle dimming and timeout behaviors
  - ✅ Battery percentage display & night light activation
  - ✅ Keyboard layout settings (add French AZERTY with fallback US)
  - ✅ Calendar and clock enhancements (date, weekday, week numbers)
  - ✅ File manager (Nautilus) settings
    - Hidden files visible
    - "Delete permanently" and "Create Link" in context menu
    - Tree view, recursive search, thumbnails always
  - ✅ GNOME Terminal customization
    - Colors, theme, transparency, profile renaming to "root"
  - ✅ GNOME Shell favorites setup (default apps pinned to dock)
  - ✅ Text Editor (Gedit/Builder-like) settings
    - Line numbers, right margin, dark theme, disable spellcheck, wrapping, grid, highlight current line
- 📦 System Hardening & Security
  - ✅ Disable root account (lock password)
  - ✅ Install USBGuard (for USB device control)
  - ✅ Disable unused services (NFS, FTP, SMTP, etc.)
  - ✅ Remove dangerous or obsolete packages (telnet, rsh, ldap-utils, etc.)
- 📦 Application Installation
  - ✅ APT software installation (list of essential tools: Nala, Vim, Zulucrypt, KeePassXC, RSSGuard, Python3, Zsh, etc.)
  - ✅ Snap apps installation (Obsidian, XMind, LSD)
  - ✅ Mullvad VPN installation via URL (.deb package)
  - ✅ Refresh snap packages
- 📦 Firefox Configuration
  - ✅ Full cleanup of Firefox profiles
  - ✅ Creation of a root profile
  - ✅ Automatic launch/close of Firefox to initialize
  - ✅ Copying custom user.js config from local file or remote (possible improvement)
- 📦 Dev & CLI Tools Configuration
  - ✅ SpaceVim installation for Vim/Neovim as IDE
  - ✅ Nerd Fonts installation (monospace fonts for terminal and editor)
  - ✅ Oh-My-Zsh installation (for advanced Zsh management)
  - ✅ Zsh customization:
    - Powerlevel10k theme installation and activation
    - Plugins installation (autosuggestions, syntax-highlighting, completions)
    - Shell switching to zsh and back (smart detection)
    - Add advanced Zsh plugins (via update_zsh_plugins):
      - git, docker, emoji, taskwarrior, kubectl, aws, terraform, etc.
  - ✅ Add custom aliases (via update_zsh_aliases): lots of productivity/pen-testing/daily-use aliases
  - ✅ Copy .p10k.zsh if exists (Powerlevel10k config)

> **Disclaimer**: Developed and officially tested on Ubuntu 23.10 (Mantic Minotaur). Also successfully tested on Ubuntu 24.04 (Noble Numbat). Compatibility with other versions is possible but not guaranteed or officially supported.

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

## 🚀 Installation

### 📥 **Direct Download** from GitHub

1. Go to GitHub repo.
2. Click `<> Code` → `Download ZIP`.
3. Extract the archive to your desired location.

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

## 🎮 Usage

Make sure the script is executable:
```bash
chmod +x ubuntu-post-install.sh
```

Then run it directly:
```bash
./ubuntu-post-install.sh
```

> ⚠️ **Note**: The script must be run with a user that has sudo rights. It will request administrator privileges automatically at start.

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

## 🤝 Contributing

We truly appreciate and welcome community involvement. Your contributions, feedback, and suggestions play a crucial role in improving the project for everyone. If you're interested in contributing or have ideas for enhancements, please feel free to open an issue or submit a pull request on our GitHub repository. Every contribution, no matter how big or small, is highly valued and greatly appreciated!

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

## 🌠 Star Evolution

Explore the star history of this project and see how it has evolved over time:

<a href="https://star-history.com/#franckferman/ubuntu-post-install&Timeline">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=franckferman/ubuntu-post-install&type=Timeline&theme=dark" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=franckferman/ubuntu-post-install&type=Timeline" />
  </picture>
</a>

Your support is greatly appreciated. We're grateful for every star! Your backing fuels our passion. ✨

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

## 📚 License

This project is licensed under the GNU Affero General Public License, Version 3.0. For more details, please refer to the LICENSE file in the repository: [Read the license on GitHub](https://github.com/franckferman/ubuntu-post-install/blob/stable/LICENSE)

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

## 📞 Contact

[![ProtonMail][protonmail-shield]](mailto:contact@franckferman.fr)
[![LinkedIn][linkedin-shield]](https://www.linkedin.com/in/franckferman)
[![Twitter][twitter-shield]](https://www.twitter.com/franckferman)

<p align="right">(<a href="#top">🔼 Back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/franckferman/ubuntu-post-install.svg?style=for-the-badge
[contributors-url]: https://github.com/franckferman/ubuntu-post-install/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/franckferman/ubuntu-post-install.svg?style=for-the-badge
[forks-url]: https://github.com/franckferman/ubuntu-post-install/network/members
[stars-shield]: https://img.shields.io/github/stars/franckferman/ubuntu-post-install.svg?style=for-the-badge
[stars-url]: https://github.com/franckferman/ubuntu-post-install/stargazers
[issues-shield]: https://img.shields.io/github/issues/franckferman/ubuntu-post-install.svg?style=for-the-badge
[issues-url]: https://github.com/franckferman/ubuntu-post-install/issues
[license-shield]: https://img.shields.io/github/license/franckferman/ubuntu-post-install.svg?style=for-the-badge
[license-url]: https://github.com/franckferman/ubuntu-post-install/blob/stable/LICENSE
[protonmail-shield]: https://img.shields.io/badge/ProtonMail-8B89CC?style=for-the-badge&logo=protonmail&logoColor=blueviolet
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=blue
[twitter-shield]: https://img.shields.io/badge/-Twitter-black.svg?style=for-the-badge&logo=twitter&colorB=blue

