# Changelog

## [0.2.0] - 2026-11-25

### Added
- Added `ecosystem-build/build-all-deb.sh` to discover sibling ecosystem repositories, validate `VERSION` files, build Flutter Linux release bundles, and package `.deb` files into `ecosystem-build/artifacts/deb/` with a summary report (`build-report.txt`).
- Added `ecosystem-build/targets.conf` as a centralized configuration file for ecosystem build targets, starting with `daftarche`.

### Changed
- Updated `build.sh` to run the transitional ecosystem `.deb` build step before ISO generation and check for `mkarchiso` availability on the host system.
- Updated `.gitignore` to ignore Archiso build directories (`work/`, `out/`), ecosystem build artifacts (`ecosystem-build/artifacts/`), and generated `*.deb` packages.
- Bumped `VERSION` from `0.1.0` to `0.2.0`.

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