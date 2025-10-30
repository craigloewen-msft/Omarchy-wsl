# Omarchy for WSL

This is a WSL-adapted version of Omarchy that brings the beautiful Omarchy Linux desktop experience to Windows Subsystem for Linux.

## Prerequisites

### Windows Requirements

- Windows 11 (build 22000 or higher) or Windows 10 (build 19041 or higher)
- WSL2 installed and configured
- WSLg (GUI support) enabled by default in recent Windows versions

### Enable Systemd in WSL

Omarchy requires systemd to be enabled in WSL. Create or edit `/etc/wsl.conf` in your WSL distribution:

```bash
sudo tee /etc/wsl.conf <<EOF
[boot]
systemd=true
EOF
```

Then restart your WSL distribution:
```powershell
# In PowerShell/CMD
wsl --shutdown
```

## Installation

### Step 1: Install Base Arch Linux in WSL

If you don't already have Arch Linux in WSL:

1. Download and install [ArchWSL](https://github.com/yuk7/ArchWSL)
2. Launch Arch Linux and create a user account
3. Update the system:
   ```bash
   sudo pacman -Syu
   ```

### Step 2: Install Omarchy

Run the installation script:

```bash
bash <(curl -sL https://raw.githubusercontent.com/craigloewen-msft/omarchy-wsl/master/boot.sh)
```

Or clone and install manually:

```bash
git clone https://github.com/craigloewen-msft/omarchy-wsl.git ~/.local/share/omarchy
cd ~/.local/share/omarchy
bash install.sh
```

The installer will automatically detect WSL and skip incompatible components.

### Step 3: Launch Desktop

After installation completes, you can start the Hyprland desktop session:

```bash
# Start Hyprland via SDDM (display manager)
sudo systemctl start sddm.service

# Or launch Hyprland directly
hyprland
```

## What Works in WSL

✅ **Desktop Environment**
- Hyprland window manager
- Waybar status bar
- Walker application launcher
- All desktop themes and styling

✅ **Applications**
- All GUI applications (VS Code, browsers, editors, etc.)
- Terminal applications
- Docker and containers
- Development tools

✅ **Features**
- Audio via WSLg (PulseAudio/PipeWire)
- Clipboard sharing with Windows
- File system access to Windows drives (`/mnt/c`, etc.)
- Network connectivity

## What's Different in WSL

The following components are automatically disabled or adapted for WSL:

❌ **Bootloader & Boot Process**
- No Limine bootloader
- No Plymouth boot splash
- No mkinitcpio/initramfs
- No kernel management (uses Windows kernel)

❌ **Hardware Management**
- No Bluetooth support
- No WiFi configuration (uses Windows networking)
- No battery management
- No power profiles
- No direct GPU driver management (uses WSLg)

❌ **Filesystem Features**
- No btrfs support
- No system snapshots (snapper)
- Uses ext4 filesystem

❌ **Low-level Hardware**
- No printer direct access
- No USB autosuspend configuration
- No hardware-specific fixes (Apple, Surface, etc.)

## Configuration

All Omarchy configuration is stored in standard locations:

- `~/.config/hypr/` - Hyprland configuration
- `~/.config/waybar/` - Status bar configuration
- `~/.config/walker/` - Application launcher
- `~/.local/share/omarchy/` - Omarchy scripts and themes

## Accessing Windows Files

Windows drives are mounted under `/mnt/`:

```bash
cd /mnt/c/Users/YourUsername/  # Access Windows user folder
```

## WSL-Specific Commands

Some Omarchy commands are modified for WSL:

- `omarchy-snapshot` - Disabled (no btrfs snapshots)
- `omarchy-refresh-limine` - Disabled (no bootloader)
- `omarchy-battery-*` - Disabled (no battery access)
- `omarchy-restart-bluetooth` - Disabled (no bluetooth)

## Troubleshooting

### Display Issues

If Hyprland doesn't start properly:

```bash
# Check WSLg is working
echo $DISPLAY
echo $WAYLAND_DISPLAY

# Restart WSL from PowerShell
wsl --shutdown
```

### Systemd Not Available

Ensure systemd is enabled in `/etc/wsl.conf` and WSL has been restarted.

### Audio Not Working

WSLg should provide audio automatically. Check:

```bash
pactl info  # Should show PulseAudio server info
```

### Permission Issues

Some operations may require adjusting WSL mount options in `/etc/wsl.conf`:

```ini
[automount]
options = "metadata,umask=22,fmask=11"
```

## Performance Tips

1. **Use WSL2 filesystem**: Store projects in the WSL filesystem (`~/`) rather than Windows filesystem (`/mnt/c/`) for better performance
2. **Allocate resources**: Configure WSL memory and CPU in `.wslconfig` (in your Windows user folder):
   ```ini
   [wsl2]
   memory=8GB
   processors=4
   ```
3. **Use Windows Terminal**: For best terminal experience with Hyprland apps

## Known Limitations

- Direct hardware access is not available
- Some system utilities that expect native hardware won't work
- Suspend/hibernate features are managed by Windows
- Network configuration is handled by Windows

## Updates

To update Omarchy in WSL:

```bash
omarchy-update
```

This works the same as native Omarchy and will maintain WSL compatibility.

## Contributing

This is a community-maintained fork of Omarchy for WSL. Contributions welcome!

## License

Omarchy is released under the [MIT License](https://opensource.org/licenses/MIT).

## Resources

- [Original Omarchy](https://omarchy.org)
- [WSL Documentation](https://learn.microsoft.com/windows/wsl/)
- [WSLg (GUI) Documentation](https://github.com/microsoft/wslg)
- [Hyprland Documentation](https://hyprland.org/)
