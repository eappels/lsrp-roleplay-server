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

## Notes

- This is a standalone utility resource.
- It does not currently expose player-facing commands.
- Keep all edits data-driven so map cleanup remains easy to maintain.