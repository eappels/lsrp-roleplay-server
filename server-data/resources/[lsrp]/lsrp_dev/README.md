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
- `/heal`: restore player health.
- `/revive`: respawn the player through the spawner flow.
- `/wep [name]`: give a predefined test weapon.
- `/veh [model]`: spawn a vehicle in front of the player.
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
- `/ids` requires ACE `lsrp.dev.ids`.