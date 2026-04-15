# lsrp_policevehicleparking

Separate emergency fleet parking resource for police and EMS vehicles.

## Scope

- Uses its own database table: `emergency_owned_vehicles`.
- Uses its own zone config and spawn points.
- Uses separate entity state keys from civilian parking.
- Serves department fleets only; civilian vehicles remain in `lsrp_vehicleparking`.

## Current Implementation

- Mission Row police fleet garage.
- Pillbox ambulance garage.
- On-demand fleet seeding for authorized police and EMS players.
- Parking retrieval/store flow forked from `lsrp_vehicleparking`.
- Separate emergency trunk stash namespace.

## Integrations

- `lsrp_police` opens the Mission Row fleet garage from its existing garage markers.
- `lsrp_ems` opens the Pillbox ambulance garage from a new EMS garage marker.
- `lsrp_vehicleparking` remains the civilian/personal vehicle parking system.

## Notes

- The database is assumed empty, so no migration logic is included.
- Fleet records are created on demand for authorized players based on `shared/config.lua` fleet definitions.
