![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/introkun/Steam-Deck.Shader-Cache-Killer-Rewamped/total) ![GitHub commit activity](https://img.shields.io/github/commit-activity/m/introkun/Steam-Deck.Shader-Cache-Killer-Rewamped)
 ![GitHub Issues or Pull Requests](https://img.shields.io/github/issues/introkun/Steam-Deck.Shader-Cache-Killer-Rewamped)



# Steam Deck: Shader Cache Killer Rewamped

Rewamped script to Purge The Steam Decks Shader Cache & Compat Data

<img src="img/example.jpg" width="100%" />

# Steam Deck: Shader Cache Mover Rewamped

Rewamped script to Symlink selected games Shader Cache & Compat Data to the SD card or External Drive

<img src="img/mover.jpg" width="100%" />

## Problem

With the 64GB version of the Steam Deck, "Other" can quickly fill your internal SSD even if you only store Games on the SD card, this "Other" is often `Shader Cache` & `CompatData`.


## Solution?

To free up some of the space you can delete the Shader Cache and/or the Compat(ability) Data, the `zShaderCacheKiller` script aims to make that process a little easier.

Rather than deleting the Shader Cache or the Compat Data, the `zShaderCacheMover` script will copy & symlink selected games Shader Cache & Compat Data to the SD card or External Drive that the game is stored, freeing up the Internal Storage.


## Is this safe?

USE AT OWN RISK

## What results can I expect?

You can free up your internal Steam Deck disk.

## How to use

## Video Guide

https://www.youtube.com/watch?v=SLGvTDGDUcY

## Simple Install

[Download this link](https://raw.githubusercontent.com/introkun/Steam-Deck.Shader-Cache-Killer/main/InstallZShaderCacheUtilities.desktop) to your **Desktop** (right click and save file) on your Steam Deck, remove the .download from the end of the file name, then double-click it.

This will install the scripts and create Steam entries.

## Run online Via Curl

In Konsole type `curl -sSL https://raw.githubusercontent.com/introkun/Steam-Deck.Shader-Cache-Killer/main/zShaderCacheKiller.sh | bash` to run `zShaderCacheKiller`

In Konsole type `curl -sSL https://raw.githubusercontent.com/introkun/Steam-Deck.Shader-Cache-Killer/main/zShaderCacheMover.sh | bash` to run `zShaderCacheMover`


## Install Via Curl

In Konsole type `curl -sSL https://raw.githubusercontent.com/introkun/Steam-Deck.Shader-Cache-Killer/main/curl_install.sh | bash`

The install script will offer to add `zShaderCacheKiller.sh` & `zShaderCacheMover.sh` to your Steam Libaray, which can be ran from `GameMode`. 

## Reinstall/Update

- Open Desktop Mode
- Launch Steam app
- Remove zShaderCacheKillerRewamped.sh and zShaderCacheMoverRewamped.sh
- If you used **Simple Install** method then you can just launch "InstallZShaderCacheUtilities" desktop icon. It will download new scripts and install newer versions into Steam.

## Uninstall

- To uninstall simply delete the install folder:
`sudo rm -r /home/deck/.local/share/introkun/SDSCK`

- Also remove the `non-steam game` links in `Steam`


# Found a Bug?

Please add to the `issues` tab! https://github.com/introkun/Steam-Deck.Shader-Cache-Killer/issues

# "This is cool! How can I thank you?"
### Why not drop a sub over on the original author's youtube channel ;) [Chinballs Gaming](https://www.youtube.com/chinballsTV?sub_confirmation=1)

### Also [Check out all these other things the original author is making](https://github.com/scawp/Steam-Deck.Tools-List)
