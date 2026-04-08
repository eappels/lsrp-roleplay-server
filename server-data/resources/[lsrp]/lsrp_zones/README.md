# LSRP Zones

## Overview

`lsrp_zones` is the generic interaction-zone resource used to open other LSRP systems from world locations.

It creates configured zones, shows the interaction prompt, and triggers the configured action event when the player presses the interaction key.

## Main Files

- `client/client.lua`: zone creation, proximity checks, prompt display, and action dispatch.
- `shared/config.lua`: zone definitions and blip settings.

## Controls

- `E`: interact with the current zone.

## Current Usage

The resource currently opens other UIs such as:

- `lsrp_pededitor`
- `lsrp_vehicleeditor`
- `lsrp_vehicleshop`

## Integrations

- Uses `polyzone` for circle-based interaction zones.
- Depends on `lsrp_framework` as the public LSRP platform entrypoint.
- Acts as a thin entry-point layer for other LSRP resources.

## Notes

- Keep zone definitions in config so new locations do not require client logic changes.
- Prompt suppression for overlapping editors is handled here when appropriate.
- Zone actions still dispatch local resource events directly; migrating those onto a framework interaction registry is a later framework milestone.