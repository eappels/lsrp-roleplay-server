# LSRP Ped Editor

## Overview

`lsrp_pededitor` is the in-game character appearance editor.

It supports model changes, component changes, and saved outfit slots per player.

## Main Files

- `client/client.lua`: editor state, camera, ped preview, clothing changes, and UI interaction.
- `server/server.lua`: outfit persistence.
- `html/`: NUI for the editor.

## Controls And Commands

- `/ped`: open or close the editor.
- `/pededitor`: open or close the editor.
- `/mask`: toggle the current mask state.
- `Z`: default keybind for mask toggle.

## Current Behavior

- Lets players edit clothing and appearance values in-game.
- Stores outfit presets in the database.
- Restores the most recent saved appearance during spawn flow when configured to do so.

## Integrations

- Uses `lsrp_core` shared config.
- Uses `oxmysql` for outfit persistence.
- Can be opened through `lsrp_zones` clothing-store interaction zones.

## Notes

- This resource is player-facing and NUI-driven.
- If appearance is not restoring correctly on spawn, inspect both this resource and `lsrp_spawner`.