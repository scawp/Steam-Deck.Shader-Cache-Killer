#!/bin/bash
#Steam Deck Shader Cache Killer by scawp and rewamped by introkun
#License: DBAD: https://raw.githubusercontent.com/introkun/Steam-Deck.Shader-Cache-Killer-Rewamped/main/LICENSE.md
#Source: https://github.com/introkun/Steam-Deck-Shader.Cache-Killer-Rewamped (original source is here https://github.com/scawp/Steam-Deck-Shader.Cache-Killer)
# Use at own Risk!

live=1
if [ "$1" = "dry-run" ]; then
  live=0
fi

#script_dir="$(dirname $(realpath "$0"))"
#conf_dir="$(dirname $(realpath "$0"))/config"
conf_dir="/tmp/introkun.SDCacheKiller"
tmp_dir="/tmp/introkun.SDCacheKiller"
timestamp_file="$conf_dir/last_download.txt"
json_file="$conf_dir/fulllist.json"
script_install_dir="/home/deck/.local/share/introkun/SDSCK"
steamapps_dir="/home/deck/.local/share/Steam/steamapps"
script_name=$(basename "$0" .sh)
log_date=$(date '+%Y-%m-%d')
logs_dir="$tmp_dir/logs"
log_file="$logs_dir/${script_name}_log_$log_date.txt"
version=$(cat "$script_install_dir/version.txt" | sed -e 's/\n//' -e 's/\r//' )

#live=0 #uncomment for debugging/testing

function log_message () {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

function log () {
  echo "$1"
  log_message "$1"
}

function log_debug () {
  log_message "$1"
  if [ $live = 0 ]; then
    echo "$1"
  fi
}

function info () {
  zenity --info --width=400 --text="$1"
}

function warning () {
  zenity --warning --width=400 --text="$1"
  log_debug "Warning: $1"
}

function info_with_timeout () {
  zenity --info --width=400 --text="$1" --timeout=1
}

function error () {
  zenity --error --width=400 --text="$1"
  log_debug "Error: $1"
}

log_debug "=== Starting $script_name script (version $version)... ==="

log_debug "Dry-Run: $live"

log_debug "Creating temporary directories..."
mkdir -p "$tmp_dir"
mkdir -p "$conf_dir"
mkdir -p "$logs_dir"
log_debug "Temporary directory created: $tmp_dir, $conf_dir and $logs_dir"

# Check if the JSON file exists and is not empty, or if 24 hours have passed since the last download
if [ ! -f "$json_file" ] || [ ! -s "$json_file" ] || [ ! -f "$timestamp_file" ] || [ $(($(date +%s) - $(date +%s -r "$timestamp_file"))) -ge 86400 ]; then
  log_debug "Downloading list of all Steam IDs..."
  
  if curl -f -o "$json_file" "https://api.steampowered.com/ISteamApps/GetAppList/v2/"; then
    log_debug "Downloaded list of all Steam IDs!"
    # Update the timestamp file
    date +%s > "$timestamp_file"
  else
    log_debug "Failed to download the list of all Steam IDs"
    exit 1;
  fi
else
  log_debug "No need to download the list of all Steam IDs, it was downloaded within the last 24 hours"
fi

log_debug "Checking for Steam Library locations..."
if [ ! -d "$steamapps_dir" ]; then
  error "Cannot find $steamapps_dir, Quitting!"
  exit 1;
fi

log_debug "Found Steam Library locations!"
#find all of the steam library locations
steamapp_dir=( $(grep -ho '"path"\s*".*"' "$steamapps_dir/libraryfolders.vdf" | sed -e 's/^"path"\s*"//' -e 's/"$/\/steamapps/') )
log_debug "Steam Library locations: ${steamapp_dir[@]}"

function get_list () {
  log_debug "Getting list of $1..."
  true > "$tmp_dir/tmp_list.txt"
  disk_usage=$(du -m --max-depth 0  "$steamapps_dir/$1"/* | sort -nr)
  echo "$disk_usage" > "$tmp_dir/tmp_list2.txt"

  log_debug "Check for symlinked folders"
  while read -r path; do
    if [ -h $path ]; then
      readlink_output=$(readlink "$path")
      if [ ! -e $path ]; then
        log_debug "Broken symlink $path pointing to $readlink_output"
        echo -e "?\t$path" >> "$tmp_dir/tmp_list.txt"
      else
        log_debug "Symlink $path pointing to $readlink_output"
        line_count=$(echo "$readlink_output" | wc -l)
        if [ ! "$line_count" -eq 1 ]; then
          warning "Symlink $path points to multiple locations: $readlink_output. Ignoring."
        else
          du -m --max-depth 0  "$(realpath $path)" >> "$tmp_dir/tmp_list.txt"
        fi
      fi
    else
      log_debug "Realpath $path is $(realpath $path)"
      du -m --max-depth 0  "$(realpath $path)" >> "$tmp_dir/tmp_list.txt"
    fi
  done <<< "$(awk '{ print $2 }' "$tmp_dir/tmp_list2.txt")"

  echo "$disk_usage" | sed 's/^.*\///' > "$tmp_dir/tmp_ids.txt"

  echo "$disk_usage" | sed -e 's/^.*\///' -e 's/^/appmanifest_/' -e 's/$/\.acf/' > "$tmp_dir/tmp_col_manifest.txt"

  true > "$tmp_dir/tmp_names.txt"

  while read -r manifest; do
    found=0
    log_debug "Checking $manifest"
    app_id="$(echo "$manifest" | sed -e "s/appmanifest_//" -e "s/\.acf//")"

    for dir in "${steamapp_dir[@]}"; do
      if [ -s  "$dir/$manifest" ]; then
        install_dir="$(grep -ho '"installdir"\s*".*"' "$dir/$manifest" | sed -e 's/^"installdir"\s*"//' -e 's/"$//')"
        echo -e "$install_dir\t " >> "$tmp_dir/tmp_names.txt"
        found=1
        break;
      fi
    done
    #TODO: This is slow, cache the results?
    if [ $found = 0 ] && [ -f "$conf_dir/fulllist.json" ] && [ -s "$conf_dir/fulllist.json" ] && [ "$app_id" -lt 100000000 ];then
      app_name="$(cat "$conf_dir/fulllist.json" | jq -r ".applist.apps[] | select(.appid == $app_id) | .name"  | head -n1)"
      if [ ! -z "$app_name" ]; then
        app_name=$(echo "$app_name" | tr -cd '[:print:]')
        echo -e "$app_name\tUninstalled?" >> "$tmp_dir/tmp_names.txt"
        found=1
      fi
    fi

    if [ $found = 0 ]; then
      #Non-steam games might be found by checking the controller_ui.txt logs
      app_id="$(echo "$manifest" | sed -e "s/appmanifest_//" -e "s/\.acf//")"
      find_in_log="$(grep -ri "AppID\s$app_id," ~/.local/share/Steam/logs/controller_ui.txt | tail -n 1 | tr -cd '[:print:]')"
      
      if [ ! -z "$find_in_log" ]; then
        echo -e "$find_in_log\tNon-Steam" | sed -e "s/.*,\s//" >> "$tmp_dir/tmp_names.txt"
      else
        #try in content_log.txt also
        find_in_log="$(grep -ri "SteamLaunch\sAppId=$app_id" ~/.local/share/Steam/logs/content_log.txt | tail -n 1)"
        if [ ! -z "$find_in_log" ]; then
          app_name=$(echo "$find_in_log" | sed -e "s/.*[=|\/]//g" -e 's/"//g' -e 's/^ //g' | tr -cd '[:print:]' | tr -d '[]')
          log_debug "Found $app_name application"
          echo -e "$app_name\tNon-Steam" >> "$tmp_dir/tmp_names.txt"
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
  selected_caches=$(zenity --list --title="Select $1 for Deletion (version $version)" \
    --width=1200 --height=720 --print-column=6 --separator="\t" \
    --ok-label "Delete selected $1!" --extra-button "$2" \
    --checklist --column="check" --column="Size (MB)" --column="App Id" --column="Name" --column="Info" --column="Real Path" \
    $(cat "$tmp_dir/tmp_merged2.txt"))
  ret_value="$?"
  unset IFS;
}

function main () {
  info_with_timeout "Welcome to Steam Deck Shader Cache Killer by scawp and rewamped by introkun"

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
    error "No $1 Selected, Quitting!"
    exit 1;
  fi

  if [ "$1" = "compatdata" ]; then
    zenity --question --width=400 \
    --text="Warning!\nDeleting compactdata will break the game!\nDeleting compactdata for a  Proton version will break Proton!\nCheck appIds on steamdb if in doubt!\nContinue at own risk!"

    if [ "$?" = 1 ]; then
      exit 1;
    fi
  fi

  log "Deleting $1..."
  (
    for selected_cache in "${selected_cache_array[@]}"; do
      ((i++))
      log "# Killing $selected_cache";
      ((percentage=($i*100/${#selected_cache_array[@]})))

      if [ $live = 1 ]; then
        rm -r "$selected_cache"
      fi

      echo "$percentage"; 
      #delay progress bar a little
      sleep 1
    done
    if [ $live = 1 ]; then
      log "# $1 Killed!"
    else
      log "# $1 Dry-Run nothing deleted!"
    fi
  ) | zenity --progress --width=400 \
    --title="Deleting $1 Dir (version $version)" \
    --percentage=0

  if [ "$?" = 1 ] ; then
    error "User Cancelled, some Cache not cleared!"
    exit 1;
  fi

  log_debug "=== Finished $script_name script ==="
  exit 0;
}

main "shadercache" "compatdata"
