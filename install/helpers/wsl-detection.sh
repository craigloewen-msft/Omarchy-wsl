#!/bin/bash

# Detect if we're running in WSL and set environment variables accordingly
detect_wsl() {
  if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    export OMARCHY_WSL_INSTALL=true
    echo "Detected WSL environment - enabling WSL-specific installation mode"
    return 0
  else
    export OMARCHY_WSL_INSTALL=false
    return 1
  fi
}

# Check if we're in WSL - this function can be used throughout install scripts
is_wsl() {
  [[ "${OMARCHY_WSL_INSTALL:-false}" == "true" ]]
}

# Run detection automatically when sourced
detect_wsl

# Export functions so they're available in subshells
export -f is_wsl
