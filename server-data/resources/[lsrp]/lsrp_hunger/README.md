# LSRP Hunger

## Overview

`lsrp_hunger` adds persistent player hunger to the LSRP framework.

It stores one hunger value per player identity, decays that value over time while the player is online, restores it when supported food items are used, and applies damage while the player is starving.

## Main Files

- `shared/config.lua`: hunger tuning such as decay rate, thresholds, and starvation damage.
- `server/server.lua`: persistence, player sync, exports, decay loop, and starvation damage.
- `client/client.lua`: lightweight client sync plus notification helpers and client exports.

## Persistence

- Hunger is stored in MySQL table `lsrp_hunger_status`.
- Rows are keyed by `license` and also track `state_id` for newer identity-aware resources.
- Hunger values are clamped between `0` and the configured max, defaulting to `100`.

## Integration

- Depends on `lsrp_core` for player identity lookup (`license`, `account_id`, `state_id`).
- Exposes server exports so other resources can add, remove, set, or read hunger.
- Exposes client exports so other resources can read the local hunger value.
- `lsrp_inventory` food items can restore hunger through this resource.

## Commands

- `/hunger`: shows your current hunger value.

## Notes

- Decay and starvation settings are intentionally conservative and should be tuned in `shared/config.lua` for your server.
- No dedicated HUD widget is included yet; hunger is published via the player state bag as `lsrp_hunger` for future UI work.