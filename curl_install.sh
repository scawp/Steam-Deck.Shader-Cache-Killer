#!/bin/bash
#Steam Deck Shader Cache Killer by scawp
#License: DBAD: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer/blob/main/LICENSE.md
#Source: https://github.com/scawp/Steam-Deck-Shader.Cache-Killer

repo_url="https://raw.githubusercontent.com/scawp/Steam-Deck.Shader-Cache-Killer/main"

tmp_dir="/tmp/scawp.SDSCK.install"

script_install_dir="/home/deck/.local/share/scawp/SDSCK"

distributor=$(lxsb_release -is 2>/dev/null)
user_id=$(id -u deck2 2>/dev/null)

#stop running script if anything returns an error (non-zero exit )
set -e

if [[ "$distributor" != "SteamOS" || "$user_id" != "1000" ]]; then
  zenity --question --width=400 \
         --text="This code has been written specifically for the Steam Deck with user 'deck'. \
               \nIt appears you are running on a different system/non-standard configuration. \
               \nAre you sure you want to continue?"
  if [ "$?" != 0 ]; then
    #NOTE: This code will never be reached due to "set -e", the system will already exit for us but just incase keep this
    echo "bye then! xxx"
    exit 1;
  fi
fi

function install_zShaderCacheKiller () {
  zenity --question --width=400 \
    --text="Read $repo_url/README.md before proceeding. \
    \nWould you like to add Shader Cache Killer to your Steam Library?"
  if [ "$?" != 0 ]; then
    #NOTE: This code will never be reached due to "set -e", the system will already exit for us but just incase keep this
    echo "bye then! xxx"
    exit 0;
  fi

  echo "Making tmp folder $tmp_dir"
  mkdir -p "$tmp_dir"

  echo "Making install folder $script_install_dir"
  mkdir -p "$script_install_dir"

  echo "Downloading Required Files"
  curl -o "$tmp_dir/zShaderCacheKiller.sh" "$repo_url/zShaderCacheKiller.sh"
  curl -o "$tmp_dir/zShaderCacheMover.sh" "$repo_url/zShaderCacheMover.sh"

  echo "Copying $tmp_dir/zShaderCacheKiller.sh to $script_install_dir/zShaderCacheKiller.sh"
  sudo cp "$tmp_dir/zShaderCacheKiller.sh" "$script_install_dir/zShaderCacheKiller.sh"

  echo "Copying $tmp_dir/zShaderCacheMover.sh to $script_install_dir/zShaderCacheMover.sh"
  sudo cp "$tmp_dir/zShaderCacheMover.sh" "$script_install_dir/zShaderCacheMover.sh"

  echo "Adding Execute and Removing Write Permissions"
  sudo chmod 555 "$script_install_dir/zShaderCacheKiller.sh"
  sudo chmod 555 "$script_install_dir/zShaderCacheMover.sh"

  add_killer="$(steamos-add-to-steam "$script_install_dir/zShaderCacheKiller.sh")"
  sleep 2;
  add_mover="$(steamos-add-to-steam "$script_install_dir/zShaderCacheMover.sh")"

}

install_zShaderCacheKiller

echo "Done."
