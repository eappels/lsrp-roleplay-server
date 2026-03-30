# lsrp_police

Private police job resource built on top of `lsrp_jobs`.

## Features

- Registers the `police_officer` job in the employment system.
- Mission Row PD duty locker marker for clocking in and out.
- Mission Row PD police-only dressing room marker that opens the clothing editor.
- Department patrol cruiser spawn and return points in the MRPD garage.
- Payroll handled through `lsrp_jobs` while officers are on duty.
- Owner-only `/policeme [grade]` self-assign command for private police testing.
- On-duty officers can use `/impound` on a faced nearby vehicle.

## Controls

- `E` at the duty marker: clock in or out.
- `E` at the dressing room marker: open the police wardrobe for clothing/accessory changes.
- `E` at the garage bay: collect a patrol cruiser while on duty.
- `E` at the return marker: return the assigned patrol vehicle.
- `/impound`: while on foot, impound the vehicle you are facing within 2 meters.

## Notes

- This is a private job, so it does not appear in the civilian job center.
- Employment must be assigned through `lsrp_jobs` exports, database tools, or a future admin/MDT workflow.
- Registered vehicles are stored in `Tow recovery unrepaired`; unregistered vehicles are removed from the world.
- The police dressing room currently reuses `lsrp_pededitor`, so it supports the same clothing component editing as public clothing stores.