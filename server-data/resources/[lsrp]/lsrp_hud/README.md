# LSRP HUD

## Overview

`lsrp_hud` owns the standalone client HUD for the vehicle compass plus lightweight player status widgets such as hunger, thirst, and in-vehicle fuel.

It exists so HUD iterations can be restarted independently without restarting `lsrp_core`.

## Main Files

- `client/client.lua`: client-side payload generation and HUD visibility control.
- `ui/index.html`: HUD NUI markup entrypoint.
- `ui/hud.css`: HUD styling and fullscreen transparent overlay layout.
- `ui/hud.js`: compass and player-status widget rendering plus NUI message handling.

## Integration

- Depends on `lsrp_framework` as the public LSRP platform entrypoint.
- Imports `@lsrp_core/shared/config.lua` to reuse existing HUD toggles and update interval settings until shared config ownership moves behind the framework.
- Reads hunger and thirst state from `lsrp_hunger`, and active vehicle fuel from `lsrp_fuel` when those resources are running.
- Reads widget layout overrides from `lsrpConfig.hudWidgets` so future HUD additions can share one central layout definition point.

## Layout Config

- Define widget anchors and mobile overrides in `lsrp_core/shared/config.lua` under `lsrpConfig.hudWidgets`.
- `needsShell` currently controls the hunger/thirst panel.
- `fuelShell` currently controls the standalone driver fuel widget.
- Future HUD widgets should add their layout definitions there first, then consume them in `lsrp_hud`.

## Notes

- A one-time full server restart is still required to unload the old embedded `lsrp_core` HUD from currently running clients.
- After that, HUD-only changes can be applied by restarting `lsrp_hud`.