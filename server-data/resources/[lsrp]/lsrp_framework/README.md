# LSRP Framework

## Overview

`lsrp_framework` is the public API facade for the LSRP platform.

It does not replace the existing service resources. Instead, it exposes a stable, easier-to-use contract over them so new resources can depend on one framework entrypoint.

## Current Scope

Version `1.0.0` is intentionally small and server-focused.

It currently wraps:

- Identity via `lsrp_core`
- Economy via `lsrp_economy`
- Jobs and permissions via `lsrp_jobs`
- Inventory lookups and item mutation via `lsrp_inventory`

## Public Exports

- `getApiVersion()`
- `getIdentity(playerSrc)`
- `getMoney(playerSrc)`
- `getJob(playerSrc)`
- `getInventory(playerSrc)`
- `getPlayerContext(playerSrc)`
- `formatCurrency(amount)`
- `canAfford(playerSrc, amount)`
- `addMoney(playerSrc, amount, reason, metadata)`
- `removeMoney(playerSrc, amount, reason, metadata)`
- `hasPermission(playerSrc, permission)`
- `hasItem(playerSrc, itemName, amount)`
- `addItem(playerSrc, itemName, amount, metadata)`
- `removeItem(playerSrc, itemName, amount)`

## Design Notes

- The facade returns normalized payloads and hides internal storage details.
- New LSRP resources should prefer `lsrp_framework` over calling multiple service resources directly.
- This resource is read-heavy by design in its first version. More advanced systems such as callbacks, registries, and notifications should be added deliberately in later versions.