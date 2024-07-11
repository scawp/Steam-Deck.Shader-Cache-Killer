#!/bin/bash
# Author: introkun

tmp_dir="/tmp/introkun.SDSCK.install"

script_install_dir="/home/deck/.local/share/introkun/SDSCK"

if zenity --question --title="Uninstall" --text="This script will uninstall zShaderCacheUtilities. Do you want to proceed?" --width=400 2>/dev/null; then
  # Delete install directory
  rm -rf "$script_install_dir"

  # Delete tmp directory
  rm -rf "$tmp_dir"

  # Remove Desktop icons
  rm -rf "$HOME"/Desktop/UninstallZShaderCacheUtilities.desktop 2>/dev/null
  rm -rf "$HOME"/Desktop/zShaderCacheKiller.desktop 2>/dev/null
  rm -rf "$HOME"/Desktop/zShaderCacheMover.desktop 2>/dev/null

  update-desktop-database ~/.local/share/applications
fi
