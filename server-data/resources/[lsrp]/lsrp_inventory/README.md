# LSRP Inventory

Rebuilt from scratch as a simple slot-based inventory resource.

## Included features

- Simple NUI with fixed slots.
- Drag and drop within your own inventory.
- Same-item stacking.
- Side-by-side target inventory for player-to-player giving.
- Split stacks with an amount modal.
- Drag to a ground drop zone to drop items.
- World pickup markers for dropped items.
- Player inventory persistence through `oxmysql`.
- Persistent named storage stashes.
- Server exports for adding and removing items.

## Controls

- Open inventory: `I`
- Close inventory: `ESC`
- Pick up world drops: `E`

## Exports

- `exports['lsrp_inventory']:getInventory(playerSrc)`
- `exports['lsrp_inventory']:addItem(playerSrc, itemName, amount, metadata)`
- `exports['lsrp_inventory']:removeItem(playerSrc, itemName, amount)`

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
- Suggested improvements: Add named stashes for trunks and gloveboxes.
