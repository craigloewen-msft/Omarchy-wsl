# Skip battery monitoring in WSL
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
  echo "WSL detected - skipping battery monitoring and power profiles"
  exit 0
fi

if ls /sys/class/power_supply/BAT* &>/dev/null; then
  # This computer runs on a battery
  powerprofilesctl set balanced || true

  # Enable battery monitoring timer for low battery notifications
  systemctl --user enable --now omarchy-battery-monitor.timer
else
  # This computer runs on power outlet
  powerprofilesctl set performance || true
fi
