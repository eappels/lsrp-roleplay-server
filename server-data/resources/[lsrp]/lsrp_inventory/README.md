# LSRP Inventory

Rebuilt from scratch as a simple slot-based inventory resource.

## Included features

- Runtime usable item registration for dynamic inventory management.
- Persistent named stashes that can be reused by systems such as vehicle storage.

## Controls


## Exports

- `exports['lsrp_inventory']:getInventory(playerSrc)`
- `exports['lsrp_inventory']:addItem(playerSrc, itemName, amount, metadata)`
- `exports['lsrp_inventory']:removeItem(playerSrc, itemName, amount)`
- `exports['lsrp_inventory']:openStashForPlayer(playerSrc, stashName, displayName, options)`

## Config

Edit `shared/config.lua` to change:

- Default slots
- Max inventory weight
- Default max stack
- Transfer / pickup ranges
- Starter items
- Item definitions

## Database Tables

- `lsrp_inventory_inventories`: Stores player inventories with `slots`, `max_weight`, and `items_json`.
- `lsrp_inventory_stashes`: Stores persistent named storage stashes.

## Notes

- World drops are runtime-only and not persisted.
- Vehicle trunk storage now reuses named persistent stashes keyed by owned vehicle id.
