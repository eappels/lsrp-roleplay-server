# LSRP Inventory

## Overview

This resource provides the inventory UI and item transfer pipeline for LSRP.

Current scope:

- NUI-based inventory window.
- In-memory inventory per player license.
- Generated vehicle key items sourced from `lsrp_vehiclebehaviour`.
- Item transfer to nearby players directly from the inventory UI.

## Controls

- Open or close inventory: `I`
- Close inventory from the UI: `ESC` or the close button
- Transfer from inventory UI: select a slot, enter target server ID, set amount, click `Transfer Selected`

## UI Flow

1. The client opens the UI and requests fresh inventory data from the server.
2. The server builds or reuses an in-memory inventory for the player's license.
3. The server injects current key-holder vehicle keys from `lsrp_vehiclebehaviour`.
4. The UI renders inventory slots.
5. Player can select an item and transfer it to a nearby target from the same UI.

## Transfer Rules

- Transfer is proximity-based (`Config.Inventory.transfer.range`).
- Key items (`vehicle_key_<PLATE>`) transfer by updating key holder in `lsrp_vehiclebehaviour`.
- Non-key items move in-memory between inventories.
- Transfers are stack-aware for future item types (`Config.Inventory.maxStack`).
- Transfer fails when the target has no available slot capacity.

## Storage Model

- Inventory is currently in-memory on the server.
- Keyed by player license.
- Created on-demand.
- Not globally persisted yet for all item types.

## Dependencies

- `lsrp_core`
- `lsrp_vehiclebehaviour` (for key items)

## Current Limitations

- Generic item persistence is not database-backed yet.
- No consent popup flow for player-to-player transfer yet.

## Files

- `client/client.lua`: inventory toggle flow, NUI callbacks, transfer request dispatch.
- `server/server.lua`: in-memory inventory, key injection, transfer rules, sync.
- `html/index.html`: inventory and transfer controls.
- `html/style.css`: inventory and transfer styling.
- `html/script.js`: rendering, selection, transfer action dispatch.
- `shared/config.lua`: slots, weight, transfer range, max stack.