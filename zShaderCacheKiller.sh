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

#script_dir="$(dirname $(realpath "$0"))"
#conf_dir="$(dirname $(realpath "$0"))/config"
conf_dir="/tmp/scawp.SDCacheKiller"
tmp_dir="/tmp/scawp.SDCacheKiller"
steamapps_dir="/home/deck/.local/share/Steam/steamapps"

#create tempory directory
mkdir -p "$tmp_dir"
mkdir -p "$conf_dir"

#download list of all steam ids if we havn't already
if [ ! -f "$conf_dir/fulllist.json" ] || [ ! -s "$conf_dir/fulllist.json" ];then 
  #TODO: Test when offline or errorcode
  curl "https://api.steampowered.com/ISteamApps/GetAppList/v2/" > "$conf_dir/fulllist.json"
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
  true > "$tmp_dir/tmp_list.txt"
  du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr > "$tmp_dir/tmp_list2.txt"
  
  while read -r path; do
    du -m --max-depth 0  "$(realpath $path)" >> "$tmp_dir/tmp_list.txt"
  done <<< "$(awk '{ print $2 }' "$tmp_dir/tmp_list2.txt")"

  du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr | sed 's/^.*\///' > "$tmp_dir/tmp_ids.txt"

  du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr | sed -e 's/^.*\///' -e 's/^/appmanifest_/' -e 's/$/\.acf/' > "$tmp_dir/tmp_col_manifest.txt"

  true > "$tmp_dir/tmp_names.txt"

  while read -r manifest; do
    found=0
    app_id="$(echo "$manifest" | sed -e "s/appmanifest_//" -e "s/\.acf//")"

    for dir in "${steamapp_dir[@]}"; do 
      if [ -s  "$dir/$manifest" ]; then
        install_dir="$(grep -ho '\"installdir\"\s*\".*\"' "$dir/$manifest" | sed -e 's/^\"installdir\"\s*\"//' -e 's/\"$//')"
        echo -e "$install_dir\t " >> "$tmp_dir/tmp_names.txt"
        #echo "$dir/$install_dir"
        #lsblk -loMOUNTPOINT,LABEL | sed "/^\/\S/\!d"
        found=1
        break
      fi
    done

    #TODO: This is slow, cache the results?
    if [ $found = 0 ] && [ -f "$conf_dir/fulllist.json" ] && [ -s "$conf_dir/fulllist.json" ] && [ "$app_id" -lt 100000000 ];then
      app_name="$(cat "$conf_dir/fulllist.json" | jq -r ".applist.apps[] | select(.appid == $app_id) | .name")"
      if [ ! -z "$app_name" ];then 
        #if [ $found = 0 ]; then
          echo -e "$app_name\tUninstalled?" >> "$tmp_dir/tmp_names.txt"
        #else
        #  echo "$app_name" >> "$tmp_dir/tmp_names.txt"
        #fi
        found=1
      fi
    fi

    if [ $found = 0 ]; then
      #Non-steam games might be found by checking the controller_ui.txt logs
      app_id="$(echo "$manifest" | sed -e "s/appmanifest_//" -e "s/\.acf//")"
      find_in_log="$(grep -ri "AppID\s$app_id," ~/.local/share/Steam/logs/controller_ui.txt | tail -n 1)"
      
      if [ ! -z "$find_in_log" ];then
       echo -e "$find_in_log\tNon-Steam" | sed -e "s/.*,\s//" >> "$tmp_dir/tmp_names.txt"
      else
        #try in content_log.txt also
        find_in_log="$(grep -ri "SteamLaunch\sAppId=$app_id" ~/.local/share/Steam/logs/content_log.txt | tail -n 1)"
        if [ ! -z "$find_in_log" ];then
          echo -e "$find_in_log\tNon-Steam" | sed -e "s/.*[=|\/]//g" -e "s/\"//g" >> "$tmp_dir/tmp_names.txt"
        else
          #we don't know
          echo -e "Unknown\tNon-Steam" >> "$tmp_dir/tmp_names.txt"
        fi
      fi
    fi
  done < "$tmp_dir/tmp_col_manifest.txt"

  paste "$tmp_dir/tmp_list.txt" "$tmp_dir/tmp_ids.txt" "$tmp_dir/tmp_names.txt" | sed -e 's/^/FALSE\t/' > "$tmp_dir/tmp_merged.txt"

  awk -F '\t' '{ print $1"\t"$2"\t"$4"\t"$5"\t"$6"\t"$3 }' "$tmp_dir/tmp_merged.txt" > "$tmp_dir/tmp_merged2.txt"

  #Don't list Proton, deleting them is Garbage Day
  sed -i '/Proton/d' "$tmp_dir/tmp_merged2.txt"
}

function gui () {
  IFS=$'[\t|\n]';
  selected_caches=$(zenity --list --title="Select $1 for Deletion" \
    --width=1200 --height=720 --print-column=6 --separator="\t" \
    --ok-label "Delete Selected!" --extra-button "$2" \
    --checklist --column="check" --column="Size (MB)" --column="Path" --column="Name" --column="Info" --column="Real Path" \
    $(cat "$tmp_dir/tmp_merged2.txt"))
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
      echo "# $1 Dry-Run nothing deleted!"
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
