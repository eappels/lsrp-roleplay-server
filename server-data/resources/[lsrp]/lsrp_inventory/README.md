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

## Suggested next improvements

- Database persistence for player inventories
- Named stashes / trunks / gloveboxes
- Item use callbacks and durability
- Nearby player list instead of typing target ID
