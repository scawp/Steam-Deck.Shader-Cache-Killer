#!/bin/bash
#Steam Deck Shader Cache Killer by scawp
#License: DBAD: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer/blob/main/LICENSE.md
#Source: https://github.com/scawp/Steam-Deck.Shader-Cache-Killer

live=1
if [ "$1" = "dry-run" ]; then
  live=0
fi

config_dir="$(dirname "$(realpath "$0")")/cacheKiller"

if [ $live = 1 ]; then
  cache_dir="/home/deck/.local/share/Steam/steamapps/shadercache"
else
  cache_dir="$config_dir/fakeShaderCache"
fi

exclude_file="$config_dir/exclude-list.txt"
temp_file="$config_dir/temp-file.txt"
delete_file="$config_dir/delete-list.txt"


#create config folder if missing
if [ ! -d "$config_dir" ]; then
  echo "creating config dir"
  mkdir "$config_dir"
fi

#create exclude file if missing
if [ ! -f "$exclude_file" ]; then
  echo "creating exclude file"
  true > "$exclude_file"
fi

#purge temp files
true > "$temp_file"
true > "$delete_file"


if [ ! -d "$cache_dir" ]; then
  if [ $live = 1 ]; then
    zenity --error --width=400 \
      --text="Cache Dir Not Found! Quitting!"
    exit 1;
  else
    echo "creating fake cache dir"
    mkdir "$cache_dir"
  fi
fi

if [ ! "$(ls -A "$cache_dir")" ]; then
  if [ $live = 1 ]; then
    zenity --error --width=400 \
      --text="Cache Dir Empty! Quitting!"
    exit 1;
  else
    echo "creating fake cache"
    for i in {1..10}; do
      mkdir "$cache_dir/$i"
    done
  fi
fi


cache_list=$(du -m --max-depth 0 \
  "$cache_dir"/* \
  | sort -nr)

while read -r line; do
  IFS=$'\t'; column=($line); unset IFS;

  if grep -q "^${column[1]}$" "$exclude_file"; then
    echo "FALSE"$'\t'"${column[0]}"$'\t'"${column[1]}" >> "$temp_file"
  else
    echo "TRUE"$'\t'"${column[0]}"$'\t'"${column[1]}" >> "$temp_file"
  fi
done <<< "$cache_list"


selected_caches=$(zenity --list --title="Select Folders for Deletion" \
  --width=1000 --height=720 --print-column=3 \
  --separator='\t' --ok-label "Delete Selected!" --extra-button "About" \
  --checklist --column="check" --column="Size" --column="Path" \
  $(cat "$temp_file"))

if [ "$?" = 1 ] ; then
  #1 means "ok" wasn't pressed, check if "about" was
  if [ "$selected_caches" = "About" ]; then
    xdg-open "https://github.com/scawp/Steam-Deck.Shader-Cache-Killer"
    #pressing about closes the script, could use some functions but meh just rerun
    exit 0;
  fi 
  zenity --error --width=400 \
    --text="User Cancelled, Quitting!"
  exit 1;
fi

IFS=$'\t'; selected_cache_array=($selected_caches); unset IFS;
i=0

if [ "${#selected_cache_array[@]}" = 0 ]; then
  zenity --error --width=400 \
  --text="No Cache Selected, Quitting!"
  exit 1;
fi


(
  echo "Size ${#selected_cache_array[@]}"
for selected_cache in "${selected_cache_array[@]}"; do
  ((i++))
  echo "# Killing $selected_cache";
  ((percentage=($i*100/${#selected_cache_array[@]})))

  rm -r "$selected_cache"
  echo "$selected_cache" >> "$delete_file"

  echo "$percentage"; 
  #delay progress bar a little
  sleep 0.5
done
echo "# Cache Killed!"
) | zenity --progress \
  --title="Deleting Cache Dir" \
  --percentage=0

if [ "$?" = 1 ] ; then
  zenity --error --width=400 \
    --text="User Cancelled, some Cache not cleared!"
  exit 1;
fi


#purge exclude file
true > "$exclude_file"
true > "$temp_file"

#add unselected items to exclude list for next time
while read -r line; do
  IFS=$'\t'; column=($line); unset IFS;
  echo "${column[1]}" >> "$temp_file"
done <<< "$cache_list"

grep -Fxvf "$delete_file" "$temp_file" > "$exclude_file"

exit 0;
