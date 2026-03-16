# LSRP Vehicle Editor

## Overview

`lsrp_vehicleeditor` is the in-game vehicle modification editor.

It provides a UI for changing performance and visual mods and supports saved vehicle setup slots.

## Main Files

- `client/client.lua`: editor flow, preview camera, vehicle mod application, and saved setup handling.
- `server/server.lua`: persistence for saved setups.
- `html/`: NUI for the editor.

## Controls And Commands

- `/vehicleeditor`: open or close the editor.
- `/veditor`: open or close the editor.

The player must normally be in the driver seat to use the editor.

## Current Features

- Performance mods.
- Visual mods.
- Wheels, colors, liveries, neon, and related customization.
- Saved setup slots per player.

## Integrations

- Uses `lsrp_core` shared configuration.
- Uses `oxmysql` for saved setup persistence.
- Can be opened through `lsrp_zones` vehicle-mod-shop interaction zones.

## Notes

- This resource is editor-focused and does not itself manage vehicle ownership.
- If a customization flow should be restricted to owned vehicles later, enforce that at the open or save path.