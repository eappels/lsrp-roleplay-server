# LSRP Dev

## Overview

`lsrp_dev` contains developer and admin helpers used during testing and local iteration.

It is not intended as a production gameplay system.

## Main Features

- Position logging.
- Heal and revive shortcuts.
- Quick weapon spawning.
- Quick vehicle spawning.
- Noclip movement.

## Commands And Controls

- `/pos`: print current coordinates and heading.
- `/heal`: restore player health (admin only).
- `/revive`: respawn the player through the spawner flow (admin only).
- `/wep [name]`: give a predefined test weapon (admin only).
- `/veh [model]`: spawn a vehicle in front of the player (admin only).
- `/devveh`: spawn your owned vehicle with plate `LS516FS` and saved props (admin only).
- `/ids`: toggle nearby overhead player IDs and names (admin only).
- `F1`: toggle noclip.
- `F3`: toggle nearby overhead player IDs and names (admin only).

## Main Files

- `client/client.lua`: test commands.
- `client/noclip.lua`: noclip logic and movement controls.

## Integrations

- Uses `lsrp_spawner` for the revive flow.

## Notes

- Treat this resource as a toolbox for development and QA.
- `/heal` requires ACE `lsrp.dev.heal`.
- `/revive` requires ACE `lsrp.dev.revive`.
- `/wep` requires ACE `lsrp.dev.wep`.
- `/veh` requires ACE `lsrp.dev.veh`.
- `/ids` requires ACE `lsrp.dev.ids`.
- `/devveh` requires ACE `lsrp.dev.devveh`.