# LSRP Map Edits

## Overview

`lsrp_mapedits` performs client-side world cleanup and map adjustments.

Its current purpose is to remove configured barriers and hide configured map props in target areas.

## Main Files

- `client/client.lua`: continuous area scanning and object removal or hiding logic.

## Current Behavior

- Searches for configured barrier models around the player.
- Removes or disables selected map blockers.
- Hides configured props within configured radii.
- Exposes barrier cleanup and debug commands for manual testing.

## Notes

- This is a standalone utility resource with `lsrp_framework` as its standard LSRP dependency.
- Player-facing status messages should go through the framework notify helper instead of ad hoc chat events.
- Keep all edits data-driven so map cleanup remains easy to maintain.