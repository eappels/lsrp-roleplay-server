# lsrp_taxi

Public taxi driver job built on top of `lsrp_jobs`, `lsrp_phones`, and `lsrp_economy`.

## Features

- Registers the `taxi_player` job in the employment system.
- Taxi depot with company taxi spawn and return markers.
- Live player-booked fares claimed from the Taxi phone app dispatch board.
- Driver payout through `lsrp_economy` when rides are completed.
- Duty state, assignment permissions, and payroll are handled through `lsrp_jobs`.

## Phone Integration

- Civilians can request a taxi from the Taxi phone app.
- Booking uses the rider's current position as pickup and the current GPS waypoint as destination.
- Riders can add a destination label, timing note, and driver notes.
- On-duty taxi drivers can refresh dispatch, claim open rides, and release unstarted rides.

## Notes

- `taxi_player` is configured as a public job and is currently the civilian taxi role exposed through the job center flow.
- Drivers must clock in and use a spawned company taxi to complete dispatch rides.
