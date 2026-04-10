# LSRP Hunger

## Overview

`lsrp_hunger` now owns both persistent player hunger and thirst for the LSRP framework.

It stores one hunger value and one thirst value per player identity, decays those values over time while the player is online, restores them when supported food or drink items are used, and applies starvation or dehydration damage plus collapse behavior when either need reaches zero.

## Main Files

- `shared/config.lua`: hunger and thirst tuning such as decay rates, thresholds, and damage values.
- `server/server.lua`: persistence, player sync, exports, decay loops, and need damage.
- `client/client.lua`: client sync, notifications, exports, and collapse behavior for both needs.

## Persistence

- Hunger is stored in MySQL table `lsrp_hunger_status`.
- Thirst is stored in MySQL table `lsrp_thirst_status`.
- Rows are keyed by `license` and also track `state_id` for newer identity-aware resources.
- Hunger and thirst values are clamped between `0` and their configured max, defaulting to `100`.

## Integration

- Depends on `lsrp_framework` for player identity lookup and shared notifications.
- Exposes server exports so other resources can add, remove, set, or read both hunger and thirst.
- Exposes client exports so other resources can read the local hunger and thirst values.
- `lsrp_inventory` food and drink items restore needs through this resource.
- Pushes percentage updates into `lsrp_hud` so both need indicators stay in sync.

## Commands

- `/hunger`: shows your current hunger value.
- `/sethunger <0-100|empty|critical|low|default|full> [playerId]`: test or admin-only hunger override, gated by ACE `lsrp.hunger.test`.
- `/thirst`: shows your current thirst value.
- `/setthirst <0-100|empty|critical|low|default|full> [playerId]`: test or admin-only thirst override, gated by ACE `lsrp.thirst.test`.

## Notes

- Decay and damage settings are intentionally conservative and should be tuned in `shared/config.lua` for your server.
- Hunger is mirrored into the HUD and player state bag as `lsrp_hunger`, and thirst as `lsrp_thirst`, so other resources can consume stable need keys while this single resource owns the implementation.