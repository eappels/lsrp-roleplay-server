# LSRP Fuel

## Overview

`lsrp_fuel` adds vehicle fuel consumption, vehicle-specific fuel tanks, a live fuel gauge, and world gas-pump refueling.

Current scope:

- Fuel drains while the local player is driving.
- Tank capacity is derived from each vehicle handling profile, so larger vehicles carry more fuel than smaller ones.
- Fuel level is synchronized on the vehicle entity so other resources can read it.
- Players can refuel vehicles at gas pumps while on foot.
- Drivers and passengers see a compact shared HUD fuel bar while inside managed vehicles.
- Fuel purchases charge LS$ through `lsrp_economy`.

## Controls

- `E`: refuel a nearby vehicle while standing next to a gas pump.

## Main Files

- `shared/config.lua`: tuning values for fuel consumption and refueling.
- `client/client.lua`: fuel tracking, pump interaction, and client exports.
- `server/server.lua`: refuel payment approval via `lsrp_economy`.

## Integrations

- `lsrp_economy`: charges LS$ for fuel purchases and credits the fuel business through `account_id`-based balance exports.
- `lsrp_vehicleparking`: already stores `fuelLevel` in vehicle props, so parked vehicles keep their fuel when they are stored and retrieved.

## Client Exports

- `getFuel(vehicle)`
- `setFuel(vehicle, fuelLevel)`
- `addFuel(vehicle, fuelDelta)`
- `isRefueling()`

## Additional Notes

- Reconciliation logic in `getVehicleFuelLevelSafe` ensures stale state updates do not cause fuel level inconsistencies.
- Integrated with `lsrp_vehicleparking` to persist fuel levels when vehicles are stored and retrieved.

## Notes

- World pump objects are used for refueling interactions.
- When `lsrp_hud` is running, the fuel gauge is rendered there as a bottom-center bar that matches the hunger/thirst widget style.
- If `lsrp_hud` is unavailable, `lsrp_fuel` falls back to its native drawn gauge.
- Vehicle classes like bicycles, boats, aircraft, and trains are excluded by default.