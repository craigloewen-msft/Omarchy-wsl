#!/bin/bash
# Omarchy WSL installer — runs INSIDE the container build (not on bare metal).
#
# This is the WSL-adapted counterpart to upstream Omarchy's ISO installer.
# Upstream targets bare-metal Arch (Limine bootloader, Btrfs root, SDDM,
# Plymouth, Hyprland, hardware drivers) via omarchy-apply-system/
# omarchy-provision-user, none of which applies in a container. So instead of
# calling those, we reuse Omarchy's real assets directly:
#
#   * the official [omarchy] pacman repo + omarchy-keyring
#   * the bin/ command suite (omarchy-*, theming, helpers)
#   * the config/ defaults and default/bash shell environment
#   * the theming system (omarchy-theme-set)
#   * install/user/all.sh for the per-user setup steps that make sense here
#
# It is meant to be run as the unprivileged `omarchy` user with passwordless
# sudo, mirroring Omarchy's user-level install model. Targets Omarchy 4.x
# ("Quattro") — see setup-omarchy.ps1 for the version pin.

set -eEo pipefail

# --- Desktop feature toggles (env, all default to enabled "1") ---------------
# DESKTOP  master switch: 1 = full Omarchy desktop, 0 = curated CLI set only.
# When DESKTOP=1, these optional groups can each be turned off independently:
#   APPS     large GUI apps (browser, office, media editors, chat, …)
#   LOGIN    display/login manager + boot splash (sddm, plymouth)
#   PRINTING CUPS printing stack + mDNS
#   INPUT    fcitx5 input methods
# Each group maps to packages/groups/<group>.packages.
DESKTOP="${DESKTOP:-1}"
APPS="${APPS:-1}"
LOGIN="${LOGIN:-1}"
PRINTING="${PRINTING:-1}"
INPUT="${INPUT:-1}"
WSLG="${WSLG:-0}"

# ARCH: amd64 (default) or arm64. On arm64 the base is Arch Linux ARM (ALARM),
# whose repos don't include the [omarchy] repo, so that's skipped and its
# packages are built from source instead (see ARM_LOCAL_PACKAGES below).
ARCH="${ARCH:-amd64}"

export OMARCHY_PATH="$HOME/.local/share/omarchy"
export OMARCHY_INSTALL="$OMARCHY_PATH/install"
export OMARCHY_MIRROR="stable"
export PATH="$OMARCHY_PATH/bin:$PATH:$HOME/.local/bin"

# Docker `RUN` doesn't set $USER/$LOGNAME the way a login shell does; several
# Omarchy scripts (e.g. omarchy-nvim-setup) reference $USER, so define them.
export USER="${USER:-$(id -un)}"
export LOGNAME="${LOGNAME:-$USER}"

# Skip background/wallpaper work that needs a running compositor.
export OMARCHY_THEME_SKIP_BACKGROUND=1

WSL_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() { echo -e "\e[32m[omarchy-wsl]\e[0m $*"; }

disable_pacman_sandbox() {
  sudo sed -i 's/^DownloadUser/#DownloadUser/' /etc/pacman.conf
  sudo grep -q '^DisableSandbox' /etc/pacman.conf || \
    sudo sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
}

# --- 1. Configure the Omarchy pacman repo + keyring -------------------------
# Skipped on arm64: ALARM's rootfs already has a working pacman.conf/mirrorlist
# and no aarch64 [omarchy] db.
if [[ $ARCH == arm64 ]]; then
  log "ARCH=arm64 — using ALARM's own pacman config (no [omarchy] repo on aarch64)"
  disable_pacman_sandbox
else
  log "Configuring Omarchy pacman repository and keyring"

  sudo cp -f "$OMARCHY_PATH/default/pacman/pacman-${OMARCHY_MIRROR}.conf" /etc/pacman.conf
  sudo cp -f "$OMARCHY_PATH/default/pacman/mirrorlist-${OMARCHY_MIRROR}" /etc/pacman.d/mirrorlist
  disable_pacman_sandbox

  sudo pacman-key --recv-keys 40DFB630FF42BCFFB047046CF0134EE680CAC571 --keyserver keys.openpgp.org
  sudo pacman-key --lsign-key 40DFB630FF42BCFFB047046CF0134EE680CAC571

  sudo pacman -Sy --noconfirm
  sudo pacman -S --noconfirm --needed --overwrite '*' omarchy-keyring
fi

# Full sync/upgrade so versions match the configured mirror.
sudo pacman -Syyuu --noconfirm

# --- 2. Install packages ----------------------------------------------------
# The package set is composed from:
#   * packages/omarchy-wsl.packages  — curated CLI core (always installed)
#   * omarchy-base.packages          — the full desktop set (when DESKTOP=1)
# minus any optional desktop groups that have been toggled off.
read_list() { grep -vE '^[[:space:]]*(#|$)' "$1"; }

declare -A want
while read -r p; do [[ -n $p ]] && want[$p]=1; done \
  < <(read_list "$WSL_DIR/../packages/omarchy-wsl.packages")

if [[ $DESKTOP == 1 ]]; then
  log "Composing FULL Omarchy desktop package set"
  while read -r p; do [[ -n $p ]] && want[$p]=1; done \
    < <(read_list "$OMARCHY_INSTALL/omarchy-base.packages")

  GROUPS_DIR="$WSL_DIR/../packages/groups"
  declare -A group_toggle=([apps]="$APPS" [login]="$LOGIN" [printing]="$PRINTING" [input]="$INPUT")
  for g in "${!group_toggle[@]}"; do
    if [[ ${group_toggle[$g]} == 0 ]]; then
      log "Desktop group '$g' disabled — excluding its packages"
      while read -r p; do [[ -n $p ]] && unset "want[$p]"; done \
        < <(read_list "$GROUPS_DIR/$g.packages")
    fi
  done
else
  log "DESKTOP=0 — installing curated CLI package set only"
fi

if [[ $WSLG == 1 ]]; then
  log "Adding lightweight WSLg application set"
  while read -r p; do [[ -n $p ]] && want[$p]=1; done \
    < <(read_list "$WSL_DIR/../packages/groups/wslg.packages")
fi

# On arm64, these packages aren't resolvable from any configured repo
# (omarchy-nvim is only in the x86_64-only [omarchy] repo; yay/mise aren't in
# ALARM's core/extra). pacman -S fails outright if any target is unresolvable,
# so pull these out and build+install from source afterwards.
ARM_LOCAL_PACKAGES=(omarchy-nvim yay mise)
if [[ $ARCH == arm64 ]]; then
  for p in "${ARM_LOCAL_PACKAGES[@]}"; do
    if [[ -n ${want[$p]:-} ]]; then
      log "ARCH=arm64 — deferring '$p' to a from-source build"
      unset "want[$p]"
    fi
  done
fi

mapfile -t packages < <(printf '%s\n' "${!want[@]}" | sort)
log "Installing ${#packages[@]} packages: ${packages[*]}"
omarchy-pkg-add "${packages[@]}"

# --- 2b. Build arm64-only packages from source ------------------------------
build_arm_local_packages() {
  local build_root
  build_root="$(mktemp -d)"

  log "Building omarchy-nvim from source (omacom-io/omarchy-pkgs)"
  git clone --depth 1 https://github.com/omacom-io/omarchy-pkgs.git "$build_root/omarchy-pkgs"
  (cd "$build_root/omarchy-pkgs/pkgbuilds/omarchy-nvim" && makepkg -si --noconfirm)

  for aur_pkg in yay-bin mise-bin; do
    log "Building $aur_pkg from AUR"
    git clone --depth 1 "https://aur.archlinux.org/${aur_pkg}.git" "$build_root/$aur_pkg"
    (cd "$build_root/$aur_pkg" && makepkg -si --noconfirm)
  done

  rm -rf "$build_root"
}
[[ $ARCH == arm64 ]] && build_arm_local_packages

# --- 3. Copy Omarchy configs + shell environment ----------------------------
log "Installing Omarchy configs and bashrc"
mkdir -p ~/.config
cp -R "$OMARCHY_PATH/config/"* ~/.config/
# default/bashrc hardcodes /usr/share/omarchy (the packaged install path) to
# find env-bootstrap — point it at ours, since OMARCHY_PATH is under $HOME
# here, not /usr/share/omarchy.
sed "s#/usr/share/omarchy#$OMARCHY_PATH#g" "$OMARCHY_PATH/default/bashrc" > ~/.bashrc

# env-bootstrap itself also defaults OMARCHY_PATH to /usr/share/omarchy unless
# /etc/omarchy.conf overrides it (the same mechanism upstream's dev-link mode
# uses for non-standard checkouts).
echo "OMARCHY_PATH=$OMARCHY_PATH" | sudo tee /etc/omarchy.conf >/dev/null

# fastfetch's config moved to a system path (/etc/fastfetch/) upstream, owned
# by the omarchy-settings package we don't build here — install it directly.
sudo mkdir -p /etc/fastfetch
sudo cp "$OMARCHY_PATH/etc/fastfetch/config.jsonc" /etc/fastfetch/config.jsonc

# --- 4. Branding -------------------------------------------------------------
log "Installing branding"
mkdir -p ~/.config/omarchy/branding
cp "$OMARCHY_PATH/icon.txt" ~/.config/omarchy/branding/about.txt
cp "$OMARCHY_PATH/logo.txt" ~/.config/omarchy/branding/screensaver.txt

# --- 5. XDG user dirs --------------------------------------------------------
log "Creating user directories"
mkdir -p ~/Downloads ~/Pictures ~/Videos ~/Projects
if omarchy-cmd-present xdg-user-dirs-update; then
  xdg-user-dirs-update --set TEMPLATES "$HOME" || true
  xdg-user-dirs-update --set PUBLICSHARE "$HOME" || true
  xdg-user-dirs-update --set DESKTOP "$HOME" || true
fi

# --- 6. Theme -----------------------------------------------------------------
# Theme state now lives under ~/.local/state/omarchy/current/ (moved from
# ~/.config/omarchy/current/ pre-Quattro).
log "Setting default theme: Tokyo Night"
mkdir -p ~/.config/omarchy/themes ~/.local/state/omarchy/current ~/.config/btop/themes
# Restart hooks for compositor apps are no-ops here (nothing is running), so
# tolerate their absence while still producing the themed config tree.
OMARCHY_THEME_HEADLESS=1 omarchy-theme-set "Tokyo Night" || true
if [[ -f ~/.local/state/omarchy/current/theme/btop.theme ]]; then
  ln -snf ~/.local/state/omarchy/current/theme/btop.theme ~/.config/btop/themes/current.theme
fi

# --- 7. Neovim ---------------------------------------------------------------
# omarchy-nvim seeds new users via /etc/skel, which useradd already copied for
# the omarchy user before this script ran; omarchy-nvim-setup just fills in
# anything still missing (e.g. after the ARM from-source build below).
if omarchy-cmd-present omarchy-nvim-setup; then
  log "Running omarchy-nvim-setup"
  omarchy-nvim-setup || true
fi

# --- 8. Per-user setup steps that make sense in WSL -------------------------
# Mirrors the lightweight parts of install/user/all.sh (theme/nvim/xdg already
# done above). Skips GUI-only steps, hardware quirks, and mise.sh's AI-agent
# CLI installs (out of scope for the curated "basic" image; network-heavy).
log "Running git/default-keyring setup"
bash -eE "$OMARCHY_INSTALL/user/git.sh"
bash -eE "$OMARCHY_INSTALL/user/default-keyring.sh"

# xcompose.sh hardcodes /usr/share/omarchy (the packaged install path), which
# doesn't exist here since OMARCHY_PATH is under $HOME — point it at ours.
tee ~/.XCompose >/dev/null <<EOF
# Run omarchy-restart-xcompose to apply changes
include "$OMARCHY_PATH/default/xcompose"
<Multi_key> <space> <n> : "$OMARCHY_USER_NAME"
<Multi_key> <space> <e> : "$OMARCHY_USER_EMAIL"
EOF

# --- 9. Mark migrations as already applied ----------------------------------
# So future `omarchy migrate`/`omarchy update` runs don't replay historical
# migrations against a fresh install.
log "Marking existing migrations as applied"
OMARCHY_MIGRATIONS_STATE_PATH=~/.local/state/omarchy/migrations
mkdir -p "$OMARCHY_MIGRATIONS_STATE_PATH"
for file in "$OMARCHY_PATH"/migrations/*.sh; do
  [[ -e $file ]] || continue
  touch "$OMARCHY_MIGRATIONS_STATE_PATH/$(basename "$file")"
done

# --- 10. Clean caches to keep the image small --------------------------------
log "Cleaning package cache"
sudo pacman -Scc --noconfirm || true

log "Omarchy WSL install complete (DESKTOP=$DESKTOP WSLG=$WSLG APPS=$APPS LOGIN=$LOGIN PRINTING=$PRINTING INPUT=$INPUT)"
