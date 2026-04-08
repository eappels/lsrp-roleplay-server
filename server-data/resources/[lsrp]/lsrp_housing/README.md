# lsrp_housing

Config-driven housing resource for this LSRP server.

Commands:
- `/housing` opens the apartment keypad.
- `/housingcatalog` opens the housing management NUI.
- `/housingkiosk` opens the housing management NUI.
- `/housingavailable [location_index]` lists available apartments.
- `/housingowned [location_index]` lists your apartments.
- `/houseenter <apartment_number>` enters one of your owned apartments.
- `/houserent <apartment_number>` rents an available apartment.
- `/housinghelp [location_index]` prints housing command help.
- `/leaveapartment` exits the current apartment instance.
- `lsrp_housing_create <apartment_number> <location_index> <price> [bucket]` creates an apartment.
- `lsrp_housing_seed <location_index> [count] [prefix] [price]` seeds sample apartments.
- `lsrp_housing_check [apartment_number|all]` checks overdue state.

Notes:
- The downloaded source resource was missing a manifest and client script, so this version recreates the same keypad/catalog/kiosk flow with working client logic.
- Rent charges and owner identity resolution now go through `lsrp_framework`.
- The NUI is enabled again with a transparent-safe bootstrap path to avoid the old fullscreen black overlay.
- Catalog and kiosk are combined in the current Alta Apartments flow, so the catalog point acts as the main management point and opens the combined owned-and-available dashboard.
- Apartment numbers use the compact original scheme (for example `1001` = location `1`, apartment instance `001`).
- Player commands accept either the full apartment number (for example `1001`) or a numeric shortcut (for example `1`) when that shortcut resolves to a single apartment.
- Edit `shared/config.lua` to add real apartment buildings and interior/exterior coordinates for your map.

## Database Schema

- `apartments` table:
  - `apartment_number`: Unique identifier for each apartment.
  - `location_index`: Index of the apartment's location.
  - `bucket`: Instance bucket for the apartment.
  - `owner_identifier`: Legacy owner license kept for compatibility and backfill support.
  - `owner_state_id`: Authoritative gameplay owner identity.
  - `price`: Purchase price of the apartment.
  - `rent_due`: Next rent due date.

## Notes

- Transparent-safe NUI bootstrap path avoids fullscreen black overlay issues.

## Preferred Exports

- `getOwned(ownerIdentity)`
- `getOwnedByStateId(stateId)`

`ownerIdentity` should be a table such as `{ stateId = 123, license = 'license:...' }` when both values are available.

## Framework Boundary

- Player identity, owner lookup, live-player lookup, money formatting, charges, refunds, and notifications now use `lsrp_framework`.
- Apartment stash access remains a direct `lsrp_inventory` integration for now.

## Deprecated Compatibility Exports

- `getOwnedByLicense(license)`

`getOwnedByLicense` remains available for older resources, but new integrations should use `getOwned(...)` or `getOwnedByStateId(...)`.