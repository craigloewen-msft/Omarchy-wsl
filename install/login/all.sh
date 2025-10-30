# Skip plymouth and bootloader in WSL
if ! is_wsl; then
  run_logged $OMARCHY_INSTALL/login/plymouth.sh
fi

run_logged $OMARCHY_INSTALL/login/default-keyring.sh
run_logged $OMARCHY_INSTALL/login/sddm.sh

# Skip bootloader/snapshot setup in WSL
if ! is_wsl; then
  run_logged $OMARCHY_INSTALL/login/limine-snapper.sh
fi
