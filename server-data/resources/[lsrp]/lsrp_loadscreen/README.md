# LSRP Loadscreen

## Overview

`lsrp_loadscreen` provides the custom loading screen shown while the player is joining the server.

It is a lightweight presentation resource that hands off cleanly to the spawn flow.

## Main Files

- `client/client.lua`: loadscreen shutdown handling.
- `index.html`: loadscreen markup.
- `style.css`: loadscreen styling.
- UI assets such as images used by the page.

## Current Behavior

- Displays a custom page during connect and load.
- Shuts down when the client is ready to transition into the game world.

## Integrations

- Uses `lsrp_framework` callback helpers for prejoin auth register/login requests.
- Works with `lsrp_spawner` so the loadscreen is dismissed during the spawn sequence.

## Notes

- This resource has no gameplay commands.
- If the loadscreen gets stuck, the spawn flow is usually the first place to inspect.
- Spawn selection still hands off directly to `lsrp_spawner`; full spawn-registry ownership is not part of the framework yet.