# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-07-19

### Added
- **Project Structure**: Established the core directory layout for the Dataist distribution using Archiso standards.
- **Base System Configuration**: Defined `profiledef.yaml`, `pacman.conf`, and essential bootloader configurations (`GRUB` & `Syslinux`).
- **Graphical Stack**: Integrated `Wayland`, `Hyprland` compositor, and `SDDM` display manager for a modern desktop environment.
- **Automation Scripts**: Developed essential lifecycle scripts:
    - `setup.sh`: Manages initial system configuration and service enabling.
    - `bridge.sh`: Handles ecosystem connectivity and bridge logic.
    - `init.sh`: Manages startup sequences for specialized services.
- **Package Management**: Configured `packages.x86_64` and implemented `pacman-hooks` (`50-system`, `60-theme`, `90-cleanup`) to ensure system integrity.
- **Containerization**: Added `Dockerfile` for isolated, reproducible builds.
- **Documentation**: Implemented structured file headers and generated project documentation via automated scripts.

### Fixed
- **Bootloader**: Refined `grub.cfg` and `syslinux.cfg` for reliable ISO booting.
- **Permissions**: Fixed file execution permissions via `profiledef.yaml` to ensure automation scripts run correctly on the live system.
- **Session Management**: Properly organized `hyprland.desktop` into `wayland-sessions` for seamless integration with SDDM.

### Improved
- **Cleanup**: Added a comprehensive `.gitignore` to prevent tracking of build artifacts (`work/`, `out/`, etc.).
- **Infrastructure**: Optimized `setup.sh` to handle graphical display initialization automatically.