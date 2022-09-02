#!/bin/bash
#Steam Deck Shader Cache Killer by scawp
#License: DBAD: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer/blob/main/LICENSE.md
#Source: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer
# Use at own Risk!

live=1
if [ "$1" = "dry-run" ]; then
  live=0
fi

#live=0 #uncomment for debugging/testing

tmp_dir="$(dirname "$(realpath "$0")")/cacheKiller"
steamapps_dir="/home/deck/.local/share/Steam/steamapps"

#create tempory directory
if [ ! -d "$tmp_dir" ]; then
  echo "creating tmp_dir dir"
  mkdir "$tmp_dir"
fi

#check we can find the steamapps directory
if [ ! -d "$steamapps_dir" ]; then
  zenity --error --width=400 \
  --text="Cannot find $steamapps_dir, Quitting!"
  exit 1;
fi

#find all of the steam library locations
steamapp_dir=( $(grep -ho '\"path\"\s*\".*\"' "$steamapps_dir/libraryfolders.vdf" | sed -e 's/^\"path\"\s*\"//' -e 's/\"$/\/steamapps/') )

function get_list () {
  du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr > "$tmp_dir/tmp_list.txt"

  du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr | sed 's/^.*\///' > "$tmp_dir/tmp_ids.txt"

  du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr | sed -e 's/^.*\///' -e 's/^/appmanifest_/' -e 's/$/\.acf/' > "$tmp_dir/tmp_col_manifest.txt"

  true > "$tmp_dir/tmp_names.txt"

  while read -r manifest; do
    found=0
    for dir in "${steamapp_dir[@]}"; do 
      if [ -s  "$dir/$manifest" ]; then
        grep -ho '\"installdir\"\s*\".*\"' "$dir/$manifest" | sed -e 's/^\"installdir\"\s*\"//' -e 's/\"$//' >> "$tmp_dir/tmp_names.txt"
        found=1
        break
      fi
    done

    if [ $found = 0 ]; then
      echo "Unknown Game" >> "$tmp_dir/tmp_names.txt"
    fi
  done < "$tmp_dir/tmp_col_manifest.txt"

  paste "$tmp_dir/tmp_list.txt" "$tmp_dir/tmp_ids.txt" "$tmp_dir/tmp_names.txt" | sed -e 's/^/FALSE\t/' > "$tmp_dir/tmp_merged.txt"

  #Don't list Proton, deleting them is Garbage Day
  sed -i '/Proton/d' "$tmp_dir/tmp_merged.txt"
}

function gui () {
  IFS=$'\t';
  selected_caches=$(zenity --list --title="Select $1 for Deletion" \
    --width=1000 --height=720 --print-column=3   --separator="\t" \
    --ok-label "Delete Selected!" --extra-button "$2" \
    --checklist --column="check" --column="Size (MB)" --column="Path" --column="ID" --column="NAME" \
    $(cat "$tmp_dir/tmp_merged.txt" | sed -e 's/$/\t/'))
  ret_value="$?"
  unset IFS;
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

  IFS=$'\t'; selected_cache_array=($selected_caches); unset IFS;
  i=0

  if [ "${#selected_cache_array[@]}" = 0 ]; then
    zenity --error --width=400 \
    --text="No $1 Selected, Quitting!"
    exit 1;
  fi

  if [ "$1" = "compatdata" ]; then
    zenity --question --width=400 \
    --text="Warning!\nDeleting compactdata will break the game!\nDeleting compactdata for a  Proton version will break Proton!\nCheck appIds on steamdb if in doubt!\nContinue at own risk!"

    if [ "$?" = 1 ]; then
      exit 1;
    fi
  fi

  (
    for selected_cache in "${selected_cache_array[@]}"; do
      ((i++))
      echo "# Killing $selected_cache";
      ((percentage=($i*100/${#selected_cache_array[@]})))

      if [ $live = 1 ]; then
        rm -r "$selected_cache"
      fi

      echo "$percentage"; 
      #delay progress bar a little
      sleep 1
    done
    if [ $live = 1 ]; then
      echo "# $1 Killed!"
    else
      echo "# Dry-Run nothing deleted!"
    fi
  ) | zenity --progress --width=400 \
    --title="Deleting $1 Dir" \
    --percentage=0

  if [ "$?" = 1 ] ; then
    zenity --error --width=400 \
      --text="User Cancelled, some Cache not cleared!"
    exit 1;
  fi

  exit 0;
}

main "shadercache" "compatdata"