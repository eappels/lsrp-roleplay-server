# LSRP Core

## Overview

`lsrp_core` provides shared configuration and common server-side persistence used by other LSRP resources.

Its primary roles are:

1. Expose the shared `lsrpConfig` table from `shared/config.lua`.
2. Persist each player's last known position so other resources can restore it on spawn.
3. Keep always-on client fundamentals, including minimap and loading-indicator suppression when configured.

It also owns account identity and the first-pass single-character profile used during prejoin.
The HUD previously embedded here has been moved to `lsrp_hud` so it can be restarted independently.

## Main Files

- `shared/config.lua`: shared default configuration consumed by other resources.
- `client/minimap.lua`: always-on client suppression for the radar and loading indicator, respecting `lsrpConfig.minimapEnabled` and `lsrpConfig.loadingIndicatorEnabled`.
- `server/identity.lua`: account identity, `account_id`, and `state_id` tracking.
- `server/characters.lua`: single-character profile persistence keyed by account.
- `server/server.lua`: player last-position storage and restore data support.

## Current Behavior

- Periodically saves player world position and heading.
- Forces a final save when a player disconnects.
- Stores positions in the `player_last_positions` table.
- Stores first-pass character profiles in the `lsrp_characters` table.
- Provides shared configuration for spawn, ped editor, vehicle editor, inventory, and other LSRP resources.

## Integrations

This resource is used by several other custom resources, including:

- `lsrp_spawner`
- `lsrp_pededitor`
- `lsrp_hud`
- `lsrp_vehicleeditor`
- `lsrp_inventory`
- `lsrp_vehicleshop`

## Notes

- This is infrastructure, not a player-facing feature resource.
- `oxmysql` is required for the last-position persistence path.