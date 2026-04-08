# LSRP Thirst

## Overview

`lsrp_thirst` adds persistent player thirst to the LSRP framework.

It stores one thirst value per player identity, decays that value over time while the player is online, restores it when supported drink items are used, and applies dehydration damage plus collapse effects when the player reaches empty thirst.

## Main Files

- `shared/config.lua`: thirst tuning such as decay rate, thresholds, and dehydration damage.
- `server/server.lua`: persistence, player sync, exports, decay loop, and dehydration damage.
- `client/client.lua`: client sync, HUD updates, notifications, and dehydration collapse behavior.

## Persistence

- Thirst is stored in MySQL table `lsrp_thirst_status`.
- Rows are keyed by `license` and also track `state_id` for newer identity-aware resources.
- Thirst values are clamped between `0` and the configured max, defaulting to `100`.

## Integration

- Depends on `lsrp_framework` for player identity lookup and shared notifications.
- Exposes server exports so other resources can add, remove, set, or read thirst.
- Exposes client exports so other resources can read the local thirst value.
- Pushes percentage updates into `lsrp_hud` so the thirst indicator stays in sync.

## Commands

- `/thirst`: shows your current thirst value.
- `/setthirst <0-100|empty|critical|low|default|full> [playerId]`: test or admin-only thirst override, gated by ACE `lsrp.thirst.test`.

## Notes

- Dehydration can apply periodic damage and force a collapse state when thirst reaches zero.
- Thirst is mirrored into the HUD and the player state bag as `lsrp_thirst` for other resources to consume.