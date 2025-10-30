# Omarchy WSL Adaptation - Implementation Summary

## Overview

This document summarizes all changes made to adapt Omarchy for Windows Subsystem for Linux (WSL) compatibility. The implementation maintains full desktop support (Hyprland, etc.) while removing incompatible hardware and bootloader dependencies.

## Files Created

### 1. **install/helpers/wsl-detection.sh**
- Detects WSL environment by checking `/proc/version` for "Microsoft" or "WSL"
- Sets `OMARCHY_WSL_INSTALL=true` environment variable
- Exports `is_wsl()` function for use throughout scripts

### 2. **install/omarchy-wsl-excluded.packages**
- Lists packages incompatible with WSL:
  - Bootloader: limine, limine-mkinitcpio-hook, limine-snapper-sync, plymouth
  - Kernel: linux, linux-firmware, linux-headers, linux-t2, linux-t2-headers
  - Filesystem: btrfs-progs, snapper
  - Bluetooth: blueberry, elephant-bluetooth
  - Power: power-profiles-daemon
  - Wireless: iwd, wireless-regdb, broadcom-wl
  - Hardware-specific: Apple, Surface, NVIDIA drivers, etc.

### 3. **install/config/wsl-waybar.sh**
- Removes bluetooth and battery modules from waybar config in WSL
- Uses jq to modify JSON configuration

### 4. **README-WSL.md**
- Comprehensive installation and usage guide
- Prerequisites (systemd, WSLg)
- What works vs. what's different
- Troubleshooting section
- Performance tips

### 5. **IMPLEMENTATION.md** (this file)
- Documents all changes made
- Reference for maintainers

## Files Modified

### Installation Scripts

#### **install/helpers/all.sh**
- Added: Source `wsl-detection.sh` first to set environment

#### **install/preflight/all.sh**
- Added: Skip `disable-mkinitcpio.sh` in WSL (no initramfs needed)

#### **install/packaging/base.sh**
- Added: Filter out packages listed in `omarchy-wsl-excluded.packages` when in WSL
- Packages are excluded before pacman installation

#### **install/config/all.sh**
- Added: Skip all hardware configuration scripts in WSL
- Added: Run `wsl-waybar.sh` to update waybar config

#### **install/login/all.sh**
- Added: Skip `plymouth.sh` in WSL (no boot splash)
- Added: Skip `limine-snapper.sh` in WSL (no bootloader/snapshots)

#### **install/first-run/battery-monitor.sh**
- Added: Exit early if running in WSL (no battery access)

### Utility Scripts

All utility scripts updated with WSL checks that exit gracefully:

#### **bin/omarchy-snapshot**
- Added: Exit with code 127 in WSL (no snapper support)

#### **bin/omarchy-refresh-limine**
- Added: Exit early in WSL (no bootloader)

#### **bin/omarchy-refresh-plymouth**
- Added: Exit early in WSL (no plymouth)

#### **bin/omarchy-battery-monitor**
- Added: Exit early in WSL (no battery)

#### **bin/omarchy-battery-remaining**
- Added: Return "100" in WSL (mock value)

#### **bin/omarchy-restart-bluetooth**
- Added: Exit early in WSL with message

## Key Design Decisions

### 1. **Conditional Execution vs. Separate Branch**
- Chose conditional execution using `is_wsl()` checks
- Maintains single codebase for both native and WSL
- Easier to keep in sync with upstream Omarchy

### 2. **Package Filtering**
- Created explicit exclusion list rather than modifying base packages
- Makes it clear what's different in WSL
- Easy to update as requirements change

### 3. **Graceful Degradation**
- Scripts that can't work in WSL exit gracefully
- No errors thrown, just informative messages
- UI elements (menu) still show options but commands handle WSL appropriately

### 4. **Desktop Support Retained**
- All Hyprland and desktop components kept intact
- SDDM display manager retained
- Full theming and UI features maintained

## Testing Checklist

When testing Omarchy WSL installation:

- [ ] WSL detection works correctly
- [ ] Excluded packages are not installed
- [ ] Installation completes without errors
- [ ] Hyprland launches successfully
- [ ] Waybar displays without bluetooth/battery modules
- [ ] Audio works through WSLg
- [ ] Applications launch correctly
- [ ] Theme switching works
- [ ] Utility scripts exit gracefully when calling hardware functions
- [ ] Update process (`omarchy-update`) works

## Future Enhancements

Potential improvements for future versions:

1. **WSL-specific optimizations**
   - Better integration with Windows clipboard
   - Optimized performance settings
   - Windows filesystem integration helpers

2. **Enhanced WSLg integration**
   - Auto-detect WSLg capabilities
   - Optimize for WSL display server

3. **Network configuration**
   - Better DNS handling for WSL2
   - VPN compatibility improvements

4. **Development workflow**
   - WSL-specific dev environment presets
   - Better Docker integration

## Maintenance Notes

### When Updating from Upstream Omarchy

1. Check for new hardware-related scripts in `install/config/hardware/`
2. Update `omarchy-wsl-excluded.packages` if new kernel/hardware packages added
3. Review any new systemd services for WSL compatibility
4. Test new utility scripts for hardware assumptions

### Adding New Hardware Features

When upstream adds new hardware features:
1. Add the feature to hardware section with `if ! is_wsl; then` wrapper
2. Update excluded packages list if new packages are required
3. Document in README-WSL.md under "What's Different"

## Architecture

```
┌─────────────────────────────────────┐
│         install.sh                  │
│  (main installation script)         │
└────────────┬────────────────────────┘
             │
             ├──> helpers/wsl-detection.sh (sets OMARCHY_WSL_INSTALL)
             │
             ├──> preflight/all.sh
             │    └─> Skips: mkinitcpio
             │
             ├──> packaging/base.sh
             │    └─> Filters: omarchy-wsl-excluded.packages
             │
             ├──> config/all.sh
             │    ├─> Runs: wsl-waybar.sh (if WSL)
             │    └─> Skips: hardware/* scripts
             │
             ├──> login/all.sh
             │    └─> Skips: plymouth.sh, limine-snapper.sh
             │
             └──> post-install/all.sh
                  └─> (no changes needed)
```

## References

- [WSL Documentation](https://learn.microsoft.com/windows/wsl/)
- [WSLg GUI Support](https://github.com/microsoft/wslg)
- [Original Omarchy](https://omarchy.org)
- [Hyprland on WSL](https://wiki.hyprland.org/)

---

**Implementation Date:** October 30, 2025
**Repository:** craigloewen-msft/omarchy-wsl
**Branch:** master
