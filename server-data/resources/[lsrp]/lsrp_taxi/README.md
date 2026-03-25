# lsrp_taxi

Player-booked taxi job built on top of `lsrp_jobs` and `lsrp_phones`.

## Features

- Registers the `taxi_player` job in the employment system.
- Taxi depot with company taxi spawn and return markers.
- Live player-booked fares claimed from the Taxi phone app dispatch board.
- Driver payout through `lsrp_economy` when rides are completed.

## Phone Integration

- Civilians can request a taxi from the Taxi phone app.
- Booking uses the rider's current position as pickup and the current GPS waypoint as destination.
- Riders can add a destination label, timing note, and driver notes.
- On-duty taxi drivers can refresh dispatch, claim open rides, and release unstarted rides.

## Notes

- Existing NPC taxi fare gameplay remains in `lsrp_taxiped`.
- This resource uses its own job id so it does not conflict with the older taxi job.
