# lsrp_towing

Public towing job built on top of `lsrp_jobs`.

## Features

- Registers the `tow_operator` job in the employment system.
- Recovery yard blip plus separate duty, spawn, and return interaction points.
- Company tow truck spawn and return flow for on-duty operators.
- Driver-side tow controls with a key mapping for attaching and detaching nearby vehicles.
- On-duty towing employees can use `/impound` to send a nearby faced vehicle into `Tow recovery unrepaired`.
- If the target is not a registered player vehicle, `/impound` removes it instead of storing it.

## Controls

- `E` at the tow yard duty marker: clock in or out.
- `E` at the tow bay: collect a company tow truck.
- `E` at the return marker: return the assigned tow truck.
- `G` by default: attach or detach a vehicle lined up behind the tow truck.
- `/impound`: while on foot, impound the vehicle you are facing within 2 meters.

## Notes

- This first pass is intentionally scoped to yard workflow and towing controls.
- Payroll is handled by `lsrp_jobs` while the player is on duty.
- `/impound` only accepts registered player vehicles and preserves their existing owner in parking storage.
- Unregistered vehicles are deleted on impound instead of being written into parking storage.
- The resource does not yet include dispatch or per-tow payouts.