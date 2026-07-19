# Dataiso - The Dataist Infrastructure Factory

Dataiso is the central repository for building and configuring the Dataist distribution based on Archiso. This repository manages all necessary components to construct an interactive, modern, and unified operating system integrated with the Asha Design system.

## Repository Structure

```text
Dataiso/
├── airootfs/                # Root filesystem content
│   ├── etc/
│   │   ├── pacman.d/        # Mirrorlist configuration
│   │   ├── sddm.conf.d/     # Display manager configuration
│   │   ├── skel/            # Default user dotfiles (e.g., .bashrc, .config)
│   │   ├── systemd/system/  # System services (e.g., dataist-setup.service)
│   │   ├── locale.conf      # Locale settings
│   │   ├── mkinitcpio.conf  # Initramfs configuration
│   │   └── fstab            # Filesystem mount points
│   ├── usr/
│   │   ├── local/bin/       # Automation scripts (setup.sh, bridge.sh, init.sh)
│   │   └── share/           # Themes and session files (hyprland.desktop)
│   └── root/                # Root user configuration
├── boot-files/              # Bootloader configurations (GRUB/Syslinux)
├── pacman-hooks/            # Pacman hooks for system management
├── profiledef.yaml          # Archiso build profile and settings
├── packages.x86_64          # List of core and ecosystem packages
├── pacman.conf              # Pacman package manager configuration
├── build.sh                 # Main build script
├── Dockerfile               # Docker environment for building
└── VERSION                  # Project version

Reference: https://wiki.archlinux.org/title/Archiso