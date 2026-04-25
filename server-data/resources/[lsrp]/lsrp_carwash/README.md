# lsrp_carwash

Simple LSRP carwash resource with a single wash-bay location and NUI flow.

## Features

- One configured carwash location at `x=24.65, y=-1391.77, z=28.89, heading=88.23`
- In-vehicle interaction prompt for drivers
- Transparent NUI shell for starting the wash
- Client-side wash action that clears dirt and decals from the current vehicle

## Files

- `shared/config.lua`: carwash location and interaction config
- `client/client.lua`: proximity checks, prompt, NUI callbacks, and wash action
- `html/`: carwash interface

## Notes

- The current version is free and client-driven.
- `server/server.lua` is intentionally minimal and can be extended later for billing or logs.