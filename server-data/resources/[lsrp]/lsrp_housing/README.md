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
- Rent charges use `lsrp_economy` bank balance through `removeBalance`/`addBalance` to match the rest of this framework.
- The NUI is enabled again with a transparent-safe bootstrap path to avoid the old fullscreen black overlay.
- Catalog and kiosk are combined in the current Alta Apartments flow, so the catalog point acts as the main management point and opens the combined owned-and-available dashboard.
- Apartment numbers use the compact original scheme (for example `1001` = location `1`, apartment instance `001`).
- Player commands accept either the full apartment number (for example `1001`) or a numeric shortcut (for example `1`) when that shortcut resolves to a single apartment.
- Edit `shared/config.lua` to add real apartment buildings and interior/exterior coordinates for your map.