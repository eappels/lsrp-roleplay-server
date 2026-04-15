# LSRP Fuel

## Overview

`lsrp_fuel` adds vehicle fuel consumption, vehicle-specific fuel tanks, a live fuel gauge, gas-pump refueling, and EV charger support.

Current scope:

- Fuel drains while the local player is driving.
- Tank capacity is derived from each vehicle handling profile, so larger vehicles carry more fuel than smaller ones.
- Fuel level is synchronized on the vehicle entity so other resources can read it.
- Players can refuel combustion vehicles at gas pumps while on foot.
- Electric vehicles can only charge at configured EV charger props.
- Drivers and passengers see a dedicated native on-screen fuel gauge while inside managed vehicles.
- Fuel purchases charge LS$ through `lsrp_framework`.

## Controls

- `E`: refuel a nearby combustion vehicle at a gas pump, or charge a nearby EV at an EV charger.

## Main Files

- `shared/config.lua`: tuning values, gas pump models, EV charger models, and EV model overrides.
- `client/client.lua`: fuel tracking, gas-pump interaction, EV charging interaction, and client exports.
- `server/server.lua`: framework-backed refuel payment approval and revenue deposit.

## Integrations

- `lsrp_framework`: charges LS$, resolves the fuel business account, and deposits business revenue.
- `lsrp_vehicleparking`: already stores `fuelLevel` in vehicle props, so parked vehicles keep their fuel when they are stored and retrieved.

## Client Exports

- `getFuel(vehicle)`
- `setFuel(vehicle, fuelLevel)`
- `addFuel(vehicle, fuelDelta)`
- `isRefueling()`

## Additional Notes

- Reconciliation logic in `getVehicleFuelLevelSafe` prefers a lower local native fuel value over a higher replicated state value while the tank is actively draining.
- This prevents stale state bag updates from snapping fuel back up between sync intervals.
- Integrated with `lsrp_vehicleparking` to persist fuel levels when vehicles are stored and retrieved.

## Notes

- World pump objects are used for combustion refueling interactions.
- World EV charger objects are used for EV charging interactions.
- The fuel gauge is drawn with native HUD functions, not a browser overlay.
- Vehicle classes like bicycles, boats, aircraft, and trains are excluded by default.