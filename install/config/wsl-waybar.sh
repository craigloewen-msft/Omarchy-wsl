#!/bin/bash

# Update waybar config for WSL by removing bluetooth and battery modules

if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
  WAYBAR_CONFIG="$HOME/.config/waybar/config.jsonc"
  
  if [ -f "$WAYBAR_CONFIG" ]; then
    echo "Updating waybar config for WSL (removing bluetooth and battery)..."
    
    # Use jq to remove bluetooth and battery from modules-right
    if command -v jq &>/dev/null; then
      TMP_FILE=$(mktemp)
      jq 'if .["modules-right"] then .["modules-right"] = (.["modules-right"] | map(select(. != "bluetooth" and . != "battery"))) else . end' "$WAYBAR_CONFIG" > "$TMP_FILE"
      mv "$TMP_FILE" "$WAYBAR_CONFIG"
      echo "Waybar config updated for WSL"
    else
      echo "Warning: jq not found, skipping waybar config update"
    fi
  fi
fi
