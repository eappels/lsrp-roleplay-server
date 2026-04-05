# LSRP HUD

## Overview

`lsrp_hud` owns the standalone client HUD for the vehicle compass plus lightweight player status widgets such as hunger, thirst, and vehicle fuel.

It exists so HUD iterations can be restarted independently without restarting `lsrp_core`.

## Main Files

- `client/client.lua`: client-side payload generation and HUD visibility control.
- `ui/index.html`: HUD NUI markup entrypoint.
- `ui/hud.css`: HUD styling and fullscreen transparent overlay layout.
- `ui/hud.js`: compass, hunger, thirst, and fuel widget rendering plus NUI message handling.

## Integration

- Imports `@lsrp_core/shared/config.lua` to reuse existing HUD toggles and update interval settings.
- Depends on `lsrp_core` for shared config availability.
- Reads hunger state from `lsrp_hunger` and thirst state from `lsrp_thirst` when those resources are running.
- Receives vehicle fuel percent updates from `lsrp_fuel` and renders them as a bottom-center bar.

## Shared Config

- `lsrpConfig.minimapEnabled`: set to `false` to keep the GTA radar hidden while `lsrp_hud` is running.
	The HUD client hard-suppresses the radar every frame with `DisplayRadar(false)`, `SetBigmapActive(false, false)`, and HUD component hides so it does not reappear during normal play.

## Notes

- A one-time full server restart is still required to unload the old embedded `lsrp_core` HUD from currently running clients.
- After that, HUD-only changes can be applied by restarting `lsrp_hud`.