# LSRP Core

## Overview

`lsrp_core` provides shared configuration and common server-side persistence used by other LSRP resources.

Its two main roles are:

1. Expose the shared `lsrpConfig` table from `shared/config.lua`.
2. Persist each player's last known position so other resources can restore it on spawn.

## Main Files

- `shared/config.lua`: shared default configuration consumed by other resources.
- `server/server.lua`: player last-position storage and restore data support.
- `client/client.lua`: currently empty.

## Current Behavior

- Periodically saves player world position and heading.
- Forces a final save when a player disconnects.
- Stores positions in the `player_last_positions` table.
- Provides shared configuration for spawn, ped editor, vehicle editor, inventory, and other LSRP resources.

## Integrations

This resource is used by several other custom resources, including:

- `lsrp_spawner`
- `lsrp_pededitor`
- `lsrp_vehicleeditor`
- `lsrp_inventory`
- `lsrp_vehicleshop`

## Notes

- This is infrastructure, not a player-facing feature resource.
- `oxmysql` is required for the last-position persistence path.