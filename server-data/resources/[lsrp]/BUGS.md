# LSRP Bug List

## Open Bugs

No currently tracked open bugs.

## Fixed Bugs

### Shops / Inventory

- Buying cola from the shop failed because the item could not be added to the inventory.
  - Root cause: `lsrp_shops` sold `cola`, but `lsrp_inventory` did not define a matching `cola` item.
  - Fix: added the missing `cola` item definition to `lsrp_inventory/shared/config.lua`.
