#!/bin/bash
#Steam Deck Shader Cache Killer by scawp
#License: DBAD: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer/blob/main/LICENSE.md
#Source: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer
# Use at own Risk!

live=1
MODE=""
if [[ "$1" = "dry-run" ]]; then
  live=0
  echo "Dry-run mode activated"
  MODE="[Dry Run]"
fi

#live=0 #uncomment for debugging/testing

#script_dir="$(dirname $(realpath "$0"))"
tmp_dir=$(mktemp -d)
declare -r tmp_dir
declare -r LIST_FILE="$tmp_dir/list.txt"
declare -r STEAMAPPS_DIR="/home/deck/.local/share/Steam/steamapps"
declare -r CACHE_DIR="/home/deck/.cache/shader-cache-killer"
declare -r CACHE_FILE="${CACHE_DIR}/infos.env"
declare -r FULL_LIST_IDS_FILE="${CACHE_DIR}/fulllist.json"
declare -a LIBRARY_FOLDERS
mapfile -t LIBRARY_FOLDERS < <(sed -nE 's@^\s*"path"\s*"([^"]*)".*@\1/steamapps@p' "$STEAMAPPS_DIR/libraryfolders.vdf")
declare -r LIBRARY_FOLDERS
declare -A INFO_CACHE
declare -r NL=$'\n'

trap 'traperror $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR
trap 'rm -rf $tmp_dir' EXIT

function traperror()  {
  local err=$1 # error status
  local line=$2 # LINENO
  local linecallfunc=$3
  local command="$4"
  local funcstack="$5"
  local now=
  now=$(date '+%d/%m/%y %T')
  echo "$now $0: ERROR '$command' failed at line $line - exited with status: $err"
  if [ "$funcstack" != "::" ]; then
    echo -n "$now $0: DEBUG Error in ${funcstack} "
    if [ "$linecallfunc" != "" ]; then
      echo "called at line $linecallfunc"
    else
      echo
    fi
  fi
  exit "$err"
}

function init() {
  local diff now ts_file
  mkdir -p "$CACHE_DIR"
  now=$(date '+%s')
  ts_file=$(stat --format='%Y' "$FULL_LIST_IDS_FILE" 2>/dev/null || echo 0)
  diff=$((now - ts_file))
  # download list of all steam ids if file is too old (1 day) or if not exists
  if [[ $diff -gt 86400 ]]; then
    #echo "Downloading full list of appids" >&2
    curl -sSLf "https://api.steampowered.com/ISteamApps/GetAppList/v2/" > "${FULL_LIST_IDS_FILE}.tmp" || true
    if [[ -s "${FULL_LIST_IDS_FILE}.tmp" ]]; then
      mv "${FULL_LIST_IDS_FILE}.tmp" "${FULL_LIST_IDS_FILE}"
    fi
  fi
}

function load_cache() {
  if [[ -f "$CACHE_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CACHE_FILE"
  fi
}

function save_cache() {
  rm -f "$CACHE_FILE"
  for id in "${!INFO_CACHE[@]}"; do
    echo "INFO_CACHE[$id]='${INFO_CACHE[$id]}'" >> "$CACHE_FILE"
  done
  # Remove Unknown entries
  sed -i "/=[']Unknown/d" "$CACHE_FILE"
}

function get_infos() {
  local appid dir info manifest name
  appid="$1"
  manifest="appmanifest_${appid}.acf"
  name=""
  # Try to find the name using the "installdir" key in the manifest
  for dir in "${LIBRARY_FOLDERS[@]}"; do
    if [[ -s "$dir/$manifest" ]]; then
      name=$(sed -nE 's@^\s*"installdir"\s*"([^"]*)".*@\1@p' "$dir/$manifest")
      if [[ -n "$name" ]];then
        info=' '; break
      fi
    fi
  done
  if [[ -z "$name" && $appid -lt 10000000 && -s "$FULL_LIST_IDS_FILE" ]]; then
    # It's a steam game try to find it's name from fulllist
    name=$(jq -r ".applist.apps[] | select(.appid == $appid).name" "$FULL_LIST_IDS_FILE" | head -n1)
    [[ -n "$name" ]] && info="Uninstalled ?"
  fi
  # Non-steam games name might be found by checking the controller_ui.txt logs
  if [[ -z "$name" ]]; then
    name=$(sed -nE "s/.*AppID\s+$appid,\s*//pi" ~/.local/share/Steam/logs/controller_ui.txt | tail -n 1)
    # if [[ -z "$name" ]];then
    #   # Try in content_log.txt
    #   name=$(sed -nE "s/.*SteamLaunch\s+AppId=$appid,\s*//pi" ~/.local/share/Steam/logs/controller_ui.txt | tail -n 1)
    # fi
  fi
  echo -e "${name:-Unknown}\t${info:-Non-Steam}"
}

function create_list () {
  local appid manifest name realpaths_file realpath size
  realpaths_file="$tmp_dir/realpaths.txt"

  shopt -u nullglob # Filename globbing patterns that don't match any filenames are simply expanded to nothing
  rm -f "$realpaths_file"
  for path in "$STEAMAPPS_DIR/$1"/*; do
    if [[ -L "$path" && ! -e "$path" ]]; then
      realpath=$(realpath "$(readlink "$path")");
      size='?'
    else
      realpath=$(realpath "$path"); tmp_size=$(du -ms "$realpath"); size=${tmp_size%%?/*}
    fi
    appid=${path##*/}
    if [[ -z ${INFO_CACHE[$appid]:-} ]];then
      infos=$(get_infos "$appid")
      INFO_CACHE[$appid]="$infos"
      #echo "[ADD] INFO CACHE $appid: $infos" >&2
    else
      infos=${INFO_CACHE[$appid]}
      #echo "HIT INFO CACHE $appid: $infos" >&2
    fi
    printf "FALSE\t%s\t%s\t%s\t%s\t%s\n" "$size" "$appid" "$infos" "$realpath" "$path" >> "$realpaths_file"
  done
  # Sort by size & remove Proton from the list
  sort -nr -k 2 "$realpaths_file" | sed -e '/Proton/d' > "$LIST_FILE"
}

function gui () {
  IFS=$'[\t|\n]';
  local -; set +o errexit; set +o errtrace # don't exit on exit status code != 0
  local selected_caches exit_code
  # shellcheck disable=SC2046
  selected_caches=$(zenity --list --title="Select $1 for Deletion $MODE" \
                           --checklist --width=1200 --height=720 \
                           --ok-label "Delete selected $1!" --extra-button "$2" \
                           --column="check" --column="Size (MB)" --column="App Id" --column="Name" --column="Info" --column="Real Path" --column="Path" \
                           --hide-column=7 --print-column=7 --separator="$NL" \
                           -- $(cat "$LIST_FILE"))
  exit_code=$?
  unset IFS
  echo "$selected_caches"
  return $exit_code
}

function main () {
  local - selected_caches exit_code

  set -o errexit  # trap on ERR in function and subshell
  set -o errtrace # inherits trap on ERR in function and subshell

  create_list "$1" "$2"

  # Show dialog to select the list of items
  set +o errexit; set +o errtrace; selected_caches=$(gui "$1" "$2"); exit_code=$?; set -o errtrace; set -o errexit

  if [[ $exit_code -eq 1 ]]; then # Cancel or extra button was selected
    case "$selected_caches" in
      "compatdata")  main "compatdata" "shadercache";;
      "shadercache") main "shadercache" "compatdata";;
    esac
    return 0
  fi

  if [[ -z "$selected_caches" ]]; then
    zenity --error --width=320 \
           --text="No $1 selected. Quitting!"
    exit 0
  fi

  declare -a selected_cache_array
  mapfile -t selected_cache_array <<< "$selected_caches"

  if [[ "$1" = "compatdata" ]]; then
    zenity --question --width=480 \
           --text="!!! Warning !!!\nDeleting compatdata will break the game!\nDeleting compactdata for a Proton version will break Proton!\nCheck appIds on steamdb if in doubt!\nContinue at own risk!\nAre you sure you want to proceed?"
    [[ $? -eq 1 ]] && return 0
  fi

  (
    local i nb_entries path percentage realpath
    i=0
    nb_entries=${#selected_cache_array[@]}
    for path in "${selected_cache_array[@]}"; do
      ((i=i+1))
      echo "# Removing $path"
      percentage=$((i * 100 / nb_entries ))

      echo "${MODE:->>} Removing $path" >&2
      if [[ $live -eq 1 ]]; then
        if [[ -L "$path" ]]; then
          realpath=$(realpath "$(readlink "$path")");
          rm -rf "$realpath" # Remove the directory
        fi
        rm -rf "$path"
      fi
      echo "$percentage";
      #delay progress bar a little
      sleep 0.5
    done
    if [[ $live -eq 1 ]]; then
      echo "# $1 Removed!"
    else
      echo "# $1 Dry-Run nothing deleted!"
    fi
  ) | zenity --progress --width=576 \
             --title="Deleting $1 Directories $MODE" \
             --percentage=0

  if [[ $? -eq 1 ]]; then
    zenity --error --width=320 \
           --text="User Cancelled, some Cache not cleared!"
  fi

  return 0
}

## Main
set -o nounset  # exit on use of uninitialized variable

init

# check we can find the steamapps directory
if [ ! -d "$STEAMAPPS_DIR" ]; then
  zenity --error --width=400 \
         --text="Cannot find $STEAMAPPS_DIR, Quitting!"
  exit 1
fi

# Try loading the cache file
load_cache

main "shadercache" "compatdata"

# Save a new cache file
save_cache
