# Install all base packages
mapfile -t packages < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-base.packages" | grep -v '^$')

# Exclude WSL-incompatible packages if in WSL
if is_wsl && [ -f "$OMARCHY_INSTALL/omarchy-wsl-excluded.packages" ]; then
  echo "WSL detected - filtering out incompatible packages..."
  mapfile -t excluded < <(grep -v '^#' "$OMARCHY_INSTALL/omarchy-wsl-excluded.packages" | grep -v '^$')
  
  # Create associative array for faster lookup
  declare -A excluded_map
  for exclude in "${excluded[@]}"; do
    excluded_map["$exclude"]=1
  done
  
  # Filter out excluded packages
  filtered_packages=()
  for pkg in "${packages[@]}"; do
    if [[ -z "${excluded_map[$pkg]}" ]]; then
      filtered_packages+=("$pkg")
    fi
  done
  packages=("${filtered_packages[@]}")
  
  echo "Filtered out ${#excluded[@]} packages for WSL compatibility"
fi

sudo pacman -S --noconfirm --needed "${packages[@]}"
