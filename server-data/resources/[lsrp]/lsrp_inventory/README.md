# LSRP Inventory

## Overview

This resource provides the current inventory UI scaffold for LSRP.

Current scope:

- NUI-based inventory window.
- In-memory inventory per player license.
- A generated vehicle key inventory item for the player's current vehicle.

This resource currently focuses on presentation and basic item transport to the UI. It is not yet a full persistent inventory system.

## Controls

- Open or close inventory: `I`
- Close inventory from the UI: `ESC` or the close button

## UI Flow

The inventory works as follows:

1. The client opens the UI and requests fresh inventory data from the server.
2. The server builds or reuses an in-memory inventory for the player's license.
3. The server ensures that a `vehicle_key_current` item exists.
4. The UI renders the returned inventory payload in the NUI grid.

## Current Vehicle Key Item

The current vehicle key shown in the inventory is a generated item with these characteristics:

- Item id: `vehicle_key_current`
- Item code: `carkey`
- Label: `Vehicle Key`
- Image: `html/images/carkey-mWjjjPPC.png`

Behavior:

1. The item is refreshed when the inventory is opened.
2. The description is updated to `Current vehicle plate: <PLATE>`.
3. If the player is not inside a vehicle when the inventory is opened, the plate falls back to `UNKNOWN`.

Important:

- This item is currently informational UI state.
- The actual vehicle authorization logic lives in `lsrp_vehiclebehaviour` and uses ownership and key data from the server, not the NUI item itself.

## Image Rendering

The UI resolves item images through the NUI resource path and falls back cleanly if an image fails to load.

That means the carkey icon is expected to render from the resource image folder without needing external hosting.

## Storage Model

The inventory is currently stored in memory on the server:

- Keyed by player license.
- Created on demand the first time the player opens the inventory.
- Not persisted to a database yet.

This is suitable for the current UI and testing flow, but not yet for long-term item persistence.

## Dependencies

- `lsrp_core`

## Current Limitations

- Inventory contents are not database-backed yet.
- The generated vehicle key item is not a full per-vehicle item system.
- Opening the inventory updates the current key item, but there is no background sync while the UI remains open.

## Files

- `client/client.lua`: inventory toggle flow, NUI focus, request and receive events.
- `server/server.lua`: in-memory inventory state and generated current-vehicle key item.
- `html/index.html`: NUI markup.
- `html/style.css`: NUI styling.
- `html/script.js`: NUI rendering and image path resolution.
- `shared/config.lua`: slot and carry-weight defaults.