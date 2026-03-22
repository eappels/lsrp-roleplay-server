# LSRP Shops

## Overview

`lsrp_shops` adds 24/7 convenience stores where players can buy configured items.

It keeps store locations and item catalogs in config, uses `lsrp_economy` for LS$ charges, and uses `lsrp_inventory` to grant purchased items.

## Main Files

- `shared/config.lua`: store locations, blips, prompts, and catalog definitions.
- `client/client.lua`: store proximity checks, markers, blips, NUI open and close flow.
- `server/server.lua`: purchase validation, LS$ charging, refund handling, and inventory grants.
- `html/`: convenience store purchase UI.

## Current Features

- Multiple 24/7 locations around the map.
- Config-driven item catalog.
- Quantity selection in the NUI.
- Optional per-item `uniquePerPlayer` purchase limits.
- Automatic refund if inventory insertion fails after payment.
- Balance refresh on open and after each purchase.

## Integrations

- `lsrp_economy`
- `lsrp_inventory`

## Notes

- Current catalog intentionally uses items that already exist in `lsrp_inventory`.
- `uniquePerPlayer = true` only checks the buyer's main inventory, not external stashes.
- If you add new shop items, define them in `lsrp_inventory/shared/config.lua` first so purchases can be granted cleanly.