# LSRP Fuel

## Overview

`lsrp_fuel` adds vehicle fuel consumption, vehicle-specific fuel tanks, a live fuel gauge, and world gas-pump refueling.

Current scope:

- Fuel drains while the local player is driving.
- Tank capacity is derived from each vehicle handling profile, so larger vehicles carry more fuel than smaller ones.
- Fuel level is synchronized on the vehicle entity so other resources can read it.
- Players can refuel vehicles at gas pumps while on foot.
- Drivers and passengers see a dedicated native on-screen fuel gauge while inside managed vehicles.
- Fuel purchases charge LS$ through `lsrp_economy`.

## Controls

- `E`: refuel a nearby vehicle while standing next to a gas pump.

## Main Files

- `shared/config.lua`: tuning values for fuel consumption and refueling.
- `client/client.lua`: fuel tracking, pump interaction, and client exports.
- `server/server.lua`: refuel payment approval via `lsrp_economy`.

## Integrations

- `lsrp_economy`: charges LS$ for fuel purchases.
- `lsrp_vehicleparking`: already stores `fuelLevel` in vehicle props, so parked vehicles keep their fuel when they are stored and retrieved.

## Client Exports

- `getFuel(vehicle)`
- `setFuel(vehicle, fuelLevel)`
- `addFuel(vehicle, fuelDelta)`
- `isRefueling()`

## Notes

- World pump objects are used for refueling interactions.
- The fuel gauge is drawn with native HUD functions, not a browser overlay.
- Vehicle classes like bicycles, boats, aircraft, and trains are excluded by default.