#!/bin/bash
#Steam Deck Shader Cache Killer by scawp
#License: DBAD: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer/blob/main/LICENSE.md
#Source: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer
# Use at own Risk!

tmp_dir="/tmp/scawp.SDCacheKiller/Mover"
steamapps_dir="/home/deck/.local/share/Steam/steamapps"

#create tempory directory
mkdir -p "$tmp_dir"

#check we can find the steamapps directory
if [ ! -d "$steamapps_dir" ]; then
  zenity --error --width=400 \
  --text="Cannot find $steamapps_dir, Quitting!"
  exit 1;
fi

function gui () {
  IFS=$'[\t|\n]';
  selected_caches=$(zenity --list --title="Select $1 to Move to Game Install Folder" \
    --width=1000 --height=720 --print-column=3 --separator="\t" \
    --ok-label "Move $1" --extra-button "$2" \
    --checklist --column="Symlink" --column="Size (MB)" --column="App Id" --column="Name" --column="Game Install Directory" \
    $(cat "$tmp_dir/move_list.txt"))
  ret_value="$?"
  unset IFS;
}


function get_list () {
  #find all of the steam library locations
  game_install_dirs=$(grep -ho '\"path\"\s*\".*\"' "/home/deck/.local/share/Steam/steamapps/libraryfolders.vdf" | sed -e 's/^\"path\"\s*\"//' -e 's/\"$/\/steamapps/' -e '/\/home\/deck\/.local\/share\/Steam\/steamapps/d')
  game_list=""

  while read -r install_dir; do
    if [ -d $install_dir ];then
      game_list="$game_list\n$(grep -o '\"installdir\"\s*\".*\"' $install_dir/*.acf | sed -e 's/appmanifest_/\t/' -e 's/\.acf\:\"installdir//' -e 's/\"\s*\"/\t/' -e 's/\"$//')"
    fi
  done <<< $game_install_dirs

  game_list="$(echo -e "$game_list")"
  #echo "$game_list"

  true > "$tmp_dir/move_list.txt"

  while read -r game_entry; do
    #0 install dir, 1 id, 2 name
    IFS=$'\t'; column=($game_entry); unset IFS;

    if [ -h "$steamapps_dir/$1/${column[1]}" ]; then
      echo "${column[1]} is a symlink"
      #echo -e "TRUE\tLINK\t${column[1]}\t${column[2]}\t${column[0]}" >> "$tmp_dir/move_list.txt"
    fi
    if [ ! -z "${column[1]}" ] && [ -d "$steamapps_dir/$1/${column[1]}" ]; then
      if [ ! -h "$steamapps_dir/$1/${column[1]}" ]; then
        size="$(du -m --max-depth 0  "$steamapps_dir/$1/${column[1]}" | sed -e 's/\s*\/.*$//')"
        echo -e "FALSE\t$size\t${column[1]}\t${column[2]}\t${column[0]}" >> "$tmp_dir/move_list.txt"
      fi
    fi
  done <<< $game_list
}


function main () {
  get_list $1 $2
  gui $1 $2

  if [ "$ret_value" = 1 ]; then
    if [ "$selected_caches" = "compatdata" ]; then
      main "compatdata" "shadercache"
    else
      if [ "$selected_caches" = "shadercache" ]; then
        main "shadercache" "compatdata"
      else  
        exit;
      fi
    fi
  fi

  if [ "$ret_value" = "1" ];then
    exit 1;
  fi
  echo "$selected_caches"
  selected_cache_array=($selected_caches);
  i=0

  if [ "${#selected_cache_array[@]}" = 0 ]; then
    zenity --error --width=400 \
    --text="No $1 Selected, Quitting!"
    exit 1;
  fi

  live=1

  (
    for selected_cache in "${selected_cache_array[@]}"; do
      ((i++))
      new_cache="$(grep -P "\t$selected_cache\t" "$tmp_dir/move_list.txt" | sed -e 's/.*\t//')$1/$selected_cache"

      echo "# Copying:\n$steamapps_dir/$1/$selected_cache\nTo:\n $new_cache";
      ((percentage=($i*100/${#selected_cache_array[@]})))
      if [ $live = 1 ]; then
        mkdir -p "$new_cache"
        cp -r "$steamapps_dir/$1/$selected_cache/"* "$new_cache/"
      fi
      sleep 2

      echo "# Deleting Original:\n$steamapps_dir/$1/$selected_cache";
      if [ $live = 1 ]; then
        rm -r "$steamapps_dir/$1/$selected_cache/"
      fi
      sleep 1

      echo "# Creating Symlink:\n$steamapps_dir/$1/$selected_cache\nFrom:\n $new_cache";
      if [ $live = 1 ]; then
        ln -s "$new_cache" "$steamapps_dir/$1/$selected_cache"
      fi
      sleep 1

      echo "$percentage"; 
    done
    if [ $live = 1 ]; then
      echo "# $1 Moved!"
    else
      echo "# Dry-Run nothing moved!"
    fi
  ) | zenity --progress --width=400 \
    --title="Moving $1" \
    --percentage=0

  if [ "$?" = 1 ] ; then
    zenity --error --width=400 \
      --text="User Cancelled, some Cache not moved!"
    exit 1;
  fi

  exit 0;
}

main "shadercache" "compatdata"