# Omarchy-wsl

Build installable **`.wsl`** packages for CLI/TUI and lightweight WSLg flavours
of [Omarchy](https://omarchy.org) using
[`wslc`](https://learn.microsoft.com/windows/wsl/).

This is a community project.

## Build

```powershell
./build-omarchy.ps1        # Omarchy-Basic.wsl
./build-omarchy-wslg.ps1   # Omarchy-WSLg.wsl
```

Both scripts fetch the upstream Omarchy sources into `omarchy/` (pinned to
`v4.0.0` — see "Upstream version" below). The basic profile provides the
terminal experience. The amd64-only WSLg profile adds Chromium, Foot, Nautilus,
Omawrite, Omacalc, media viewers, and Windows-launchable application entries.
It runs individual Linux applications through WSLg; it does not run Hyprland
or provide a complete Linux desktop.

## Install

```powershell
wsl --install --from-file Omarchy-Basic.wsl
wsl -d Omarchy

wsl --install --from-file Omarchy-WSLg.wsl
wsl -d Omarchy-WSLg
```

You land in a login shell as the `omarchy` user with the Omarchy command suite,
Tokyo Night theming, and the headline CLI tools (`bat`, `eza`, `fzf`, `rg`,
`lazygit`, `nvim`, `btop`, …).

The WSLg profile additionally registers launchers such as **Omarchy Terminal**,
**Omarchy Files**, **Omarchy Browser**, **Omawrite**, **Omacalc**, **Omarchy
Neovim**, and **Omarchy System Monitor** with Windows.

## Architecture support (amd64 / arm64)

Both x86_64 (`amd64`) and ARM64 (`arm64`) are supported by the basic profile.
`build.ps1` and `build-omarchy.ps1` auto-detect the host architecture; override with
`-Arch amd64` / `-Arch arm64` if needed. wslc can't cross-build, so build on
the target architecture. The WSLg profile currently supports amd64 only because
its Omarchy GUI packages are distributed through the x86_64-only repository.

Upstream Arch's Docker image and Omarchy's `[omarchy]` pacman repo are both
x86_64-only, so the arm64 build boots from the official
[Arch Linux ARM](https://archlinuxarm.org) rootfs instead, and builds the few
packages missing from its repos (`omarchy-nvim`, `yay`, `mise`) from source.
See `install/omarchy-wsl-install.sh` for details.

## Upstream version

`setup-omarchy.ps1` pins the Omarchy checkout to **`v4.0.0`** ("Quattro") by
default. Pass `-Ref` to override, but re-verify the installer against that
layout first — upstream has restructured `install/` before between releases.

## Requirements

- Windows with **WSL** and the **`wslc`** CLI (`wslc.exe` on `PATH`)
- **Git** and **PowerShell 5.1+**

## License

MIT. Omarchy itself is maintained upstream by Basecamp under the
[MIT License](https://github.com/basecamp/omarchy/blob/master/LICENSE).
