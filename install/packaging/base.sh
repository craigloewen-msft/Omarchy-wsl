# Install all base packages
mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-base.packages" | grep -v '^$')

# Exclude WSL-incompatible packages if in WSL
if is_wsl && [ -f "$OMARCHY_INSTALL/omarchy-wsl-excluded.packages" ]; then
  echo "WSL detected - filtering out incompatible packages..."
  mapfile -t excluded < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-wsl-excluded.packages" | grep -v '^$')
  
  # Filter out excluded packages
  for exclude in "${excluded[@]}"; do
    packages=("${packages[@]/$exclude}")
  done
  
  # Remove empty elements
  packages=("${packages[@]}")
fi

sudo pacman -S --noconfirm --needed "${packages[@]}"
