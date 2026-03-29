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
- `/devveh`: spawn your owned vehicle with plate `LSRP001` and saved props (admin only).
- `/ids`: toggle nearby overhead player IDs and names locally.
- `/devadmin add [playerId]`: grant dev admin rights to an online player.
- `/devadmin remove [playerId]`: revoke dev admin rights from an online player.
- `/devadmin list`: list all persisted dev admins.
- `F1`: toggle noclip.
- `F3`: show nearby overhead player IDs and names while held.

## Main Files

- `client/client.lua`: test commands.
- `client/noclip.lua`: noclip logic and movement controls.
- `sql/schema.sql`: database schema for the persisted dev admin table.

## Integrations

- Uses `lsrp_spawner` for the revive flow.

## Notes

- Treat this resource as a toolbox for development and QA.
- Dev permissions now come from one system: the persisted `dev_admins` database table.
- `/devadmin` can be used by console or an existing dev admin.
- Existing `data/admins.json` entries are migrated into the database automatically the first time the resource starts against an empty `dev_admins` table.
- Bootstrap the first admin from server console with `/devadmin add [playerId]` while the target player is online.
- If you want the first admin to be seeded automatically after a reset, add either `setr lsrp_dev.bootstrap_license license:...` or `setr lsrp_dev.bootstrap_state_id ...` in `server.cfg`; when the admin table is empty, the matching player will be auto-added on join.
- If you want to bootstrap the first admin in game without a convar, give that player ACE `lsrp.dev.manageadmins`; this ACE is only used while the admin list is still empty.
- `/heal`, `/revive`, `/wep`, `/veh`, `/setplate`, `/devveh`, and `/identityaudit` all use the dev admin list.
- `/ids` and `F3` are client-side and available to everyone.