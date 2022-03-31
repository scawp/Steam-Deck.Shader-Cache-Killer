# Steam Deck: Shader Cache Killer

Script to Purge The Steam Decks Shader Cache

## Problem

With the 64GB verson of the Steam Deck, "Other" can quicky fill your internal SSD even if you only store Games on the SD card.

For me this was a result of installing the same game several times on different SD cards which then prevented me from installing other games.

## Solution?

To free up some of the space you can delete the Shader Cache, this script aims to make that process a little easier.

## Why not Compdata also?

I tested this and it broke all my Proton installs with no easy way to repair other than a Factory Reset, more research is required for other locations.

## Is this safe?

This has had limited testing on one system, USE AT OWN RISK

## What 

## What results can I expect?

For me I has 16.2GB of "Other" data, running this dropped this down to ~7GB

## How to use

Open `Konsole` and choose a place you want to download (I like to have all my Git Repositories in `/home/deck/repo` ( `mkdir /home/deck/repo` )

1 clone the repo `git clone git@github.com:scawp/Steam-Deck.Shader-Cache-Killer.git`

2 run `./zShaderCacheKiller.sh`

3 Select Caches you wish to Delete, they are ordered by Size

4 Click `Delete Selected!`

## Adding to Steam

You can also add this as a non-steam game if desired, icons and banner art provided in `steamArt`
