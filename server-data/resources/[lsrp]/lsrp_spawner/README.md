# LSRP Spawner

## Overview

`lsrp_spawner` handles player spawn and respawn flow.

It restores saved position data, applies spawn model information, dismisses the loadscreen, and places the player safely into the world.

## Main Files

- `client/client.lua`: spawn execution, model application, loadscreen teardown, and ground correction.
- `server/server.lua`: reads saved spawn-related data and sends it to the client.

## Current Behavior

- Restores the player's last saved world position when available.
- Falls back to configured default spawn data when needed.
- Applies model data before finishing the spawn sequence.
- Performs ground validation and correction during spawn placement.

## Export

- `spawnPlayerDirect(spawn)`

This is used for direct respawn flows such as development revive helpers.

## Integrations

- Uses `lsrp_core` for shared config and saved position infrastructure.
- Uses `oxmysql` for persisted spawn data.
- Works with `lsrp_loadscreen` so the player exits the loadscreen cleanly.
- Works with `lsrp_pededitor` outfit restore flow.
- Used by `lsrp_dev` for `/revive`.

## Notes

- If players spawn underground or at bad heights, inspect the spawn ground-correction path first.