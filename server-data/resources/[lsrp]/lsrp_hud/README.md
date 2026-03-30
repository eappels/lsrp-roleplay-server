# LSRP HUD

## Overview

`lsrp_hud` owns the standalone client HUD for compass, heading, street name, and XYZ coordinates.

It exists so HUD iterations can be restarted independently without restarting `lsrp_core`.

## Main Files

- `client/client.lua`: client-side payload generation and HUD visibility control.
- `ui/index.html`: HUD NUI markup.
- `ui/style.css`: HUD styling and fullscreen transparent overlay layout.
- `ui/app.js`: compass rendering and NUI message handling.

## Integration

- Imports `@lsrp_core/shared/config.lua` to reuse existing HUD toggles and update interval settings.
- Depends on `lsrp_core` for shared config availability.

## Notes

- A one-time full server restart is still required to unload the old embedded `lsrp_core` HUD from currently running clients.
- After that, HUD-only changes can be applied by restarting `lsrp_hud`.